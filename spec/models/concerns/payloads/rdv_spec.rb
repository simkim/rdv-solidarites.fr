# frozen_string_literal: true

describe Payloads::Rdv, type: :service do
  describe "#payload" do
    %i[name ical_uid summary ends_at sequence description address].each do |key|
      it "return an hash with key #{key}" do
        user = build(:user)
        rdv = build(:rdv, users: [user])
        expect(rdv.payload).to have_key(key)
      end
    end

    describe ":name" do
      let(:user) { build(:user) }
      let(:rdv) { build(:rdv, users: [user], starts_at: Time.zone.parse("20201123 15h50")) }

      it { expect(rdv.payload[:name]).to eq("rdv-#{rdv.uuid}-2020-11-23-15-50-00-0100.ics") }
    end

    describe ":starts_at" do
      let(:user) { build(:user) }
      let(:starts_at) { Time.zone.parse("20201123 15h50") }
      let(:rdv) { build(:rdv, users: [user], starts_at: starts_at) }

      it { expect(rdv.payload[:starts_at]).to eq(starts_at) }
    end

    describe ":ends_at" do
      let(:user) { build(:user) }
      let(:starts_at) { Time.zone.parse("20201123 15h50") }
      let(:rdv) { build(:rdv, users: [user], starts_at: Time.zone.parse("20201123 15h50"), duration_in_min: 10) }

      it { expect(rdv.payload[:ends_at]).to eq(starts_at + 10.minutes) }
    end

    describe ":sequence" do
      let(:user) { build(:user) }
      let(:rdv) { build(:rdv, users: [user], sequence: 1) }

      it { expect(rdv.payload[:sequence]).to eq(1) }
    end

    describe ":description" do
      let(:user) { build(:user) }
      let(:rdv) { build(:rdv, users: [user]) }

      it { expect(rdv.payload[:description]).to eq("Infos et annulation: #{ENV['HOST']}/r") }
    end

    describe ":address" do
      let(:user) { build(:user) }

      context "with a phone motif" do
        let(:rdv) { build(:rdv, users: [user], motif: build(:motif, :by_phone)) }

        it { expect(rdv.payload[:address]).to be_nil }
      end

      context "without a phone motif" do
        let(:rdv) { build(:rdv, users: [user], motif: build(:motif, :public_office), lieu: build(:lieu, address: "17 rue de l'adresse")) }

        it { expect(rdv.payload[:address]).to eq("17 rue de l'adresse") }
      end
    end

    describe ":ical_uid" do
      let(:user) { create(:user) }
      let(:rdv) { create(:rdv, users: [user]) }

      it { expect(rdv.payload[:ical_uid]).to eq(rdv.uuid) }
    end

    describe ":summary" do
      let(:user) { build(:user, first_name: "Ethan", last_name: "DUVAL") }
      let(:rdv) { build(:rdv, users: [user], motif: build(:motif, name: "Consultation")) }

      it { expect(rdv.payload[:summary]).to eq("RDV Consultation") }
    end
  end
end
