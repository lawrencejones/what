# frozen_string_literal: true

require "spec_helper"
require "support/payment"
require "support/create_payment"
require "support/blow_up"
require "support/what_job"

require "date"

RSpec.describe What::Worker do
  subject do
    -> { described_class.work("default") }
  end

  describe ".work" do
    context "with a single job on the default queue" do
      before do
        CreatePayment.enqueue(5)
      end

      it "works and then destroys the job" do
        expect(WhatJob.count).to eq(1)
        subject.call
        expect(Payment.count).to eq(1)
        expect(WhatJob.count).to eq(0)
      end
    end

    context "with multiple jobs on the default queue" do
      before do
        CreatePayment.enqueue(3)
        CreatePayment.enqueue(4)
      end

      it "works one job" do
        expect(WhatJob.count).to eq(2)
        subject.call
        expect(Payment.count).to eq(1)
        subject.call
        expect(Payment.count).to eq(2)
        expect(WhatJob.count).to eq(0)
      end
    end

    context "with a job scheduled to run in the future" do
      before do
        CreatePayment.enqueue(1, run_at: Date.today + 100)
      end

      it "doesn't work the job" do
        subject.call
        expect(WhatJob.count).to eq(1)
        expect(WhatJob.first.failed_at).to eq(nil)
      end
    end

    context "when a job fails" do
      before { BlowUp.enqueue }

      it "marks the job as failed, recording the stack trace" do
        subject.call
        expect(WhatJob.count).to eq(1)
        failed_job = WhatJob.first
        expect(failed_job.last_error).to match(/oh noes!/)
        expect(failed_job.error_count).to eq(1)
        expect(failed_job.runnable).to eq(false)
        expect(failed_job.failed_at).not_to be_nil
        expect(failed_job.runnable).to eq(false)
      end

      it "doesn't attempt to re-run the job" do
        subject.call
        subject.call
        expect(WhatJob.first.error_count).to eq(1)
      end
    end
  end
end
