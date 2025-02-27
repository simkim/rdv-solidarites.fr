# frozen_string_literal: true

describe Users::BaseSms, type: :service do
  describe "#tags" do
    subject { described_class.new(rdv, build(:user), token).tags }

    let!(:territory77) { create(:territory, departement_number: "77") }
    let(:organisation) { create(:organisation, territory: territory77) }
    let(:rdv) { build(:rdv, organisation: organisation) }
    let(:token) { "123456" }

    it do
      expect(subject).to include("org-#{organisation.id}")
      expect(subject).to include("dpt-77")
      expect(subject).to include("base_sms")
    end
  end
end
