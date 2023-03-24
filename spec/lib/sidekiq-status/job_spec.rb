require 'spec_helper'

describe Sidekiq::Status::Job do

  let!(:job_id) { SecureRandom.hex(12) }

  describe ".perform_async" do
    it "generates and returns job id" do
      allow(SecureRandom).to receive(:hex).once.and_return(job_id)
      expect(StubJob.perform_async()).to eq(job_id)
    end
  end

  describe ".expiration" do
    subject { StubJob.new }

    it "allows to set/get expiration" do
      expect(subject.expiration).to be_nil
      subject.expiration = :val
      expect(subject.expiration).to eq(:val)
    end
  end

  describe ".at" do
    subject { StubJob.new }

    it "records when the worker has started" do
      expect { subject.at(0) }.to(change { subject.retrieve('working_at') })
    end

    context "when setting the total for the worker" do
      it "records when the worker has started" do
        expect { subject.total(100) }.to(change { subject.retrieve('working_at') })
      end
    end

    it "records when the worker last worked" do
      expect { subject.at(0) }.to(change { subject.retrieve('update_time') })
    end
  end
end
