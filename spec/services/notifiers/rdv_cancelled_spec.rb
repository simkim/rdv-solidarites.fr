# frozen_string_literal: true

describe Notifiers::RdvCancelled, type: :service do
  subject { described_class.perform_with(rdv, author) }

  let(:agent1) { build(:agent) }
  let(:agent2) { build(:agent) }
  let(:user) { build(:user) }
  let(:rdv) { build(:rdv, starts_at: starts_at, agents: [agent1, agent2]) }
  let(:rdv_user) { create(:rdvs_user, user: user, rdv: rdv) }
  let(:rdvs_users) { RdvsUser.where(id: rdv_user.id) }
  let(:token) { "123456" }

  before do
    rdv.update!(status: new_status)

    allow(Agents::RdvMailer).to receive(:rdv_cancelled).and_return(instance_double(ActionMailer::MessageDelivery, deliver_later: nil))
    allow(Users::RdvMailer).to receive(:rdv_cancelled).and_return(instance_double(ActionMailer::MessageDelivery, deliver_later: nil))
    allow(rdv).to receive(:rdvs_users).and_return(rdvs_users)
    allow(rdvs_users).to receive(:where).and_return([rdv_user])
    allow(rdv_user).to receive(:new_raw_invitation_token).and_return(token)
  end

  context "cancellation by agent" do
    let(:author) { agent1 }
    let(:new_status) { :revoked }

    context "starts in more than 2 days" do
      let(:starts_at) { 3.days.from_now }

      it "only notifies the user" do
        expect(Agents::RdvMailer).not_to receive(:rdv_cancelled).with(rdv, agent1, agent1)
        expect(Agents::RdvMailer).not_to receive(:rdv_cancelled).with(rdv, agent2, agent1)
        expect(Users::RdvMailer).to receive(:rdv_cancelled).with(rdv, user, token)

        subject
        expect(rdv.events.where(event_type: RdvEvent::TYPE_NOTIFICATION_MAIL, event_name: "cancelled_by_agent").count).to eq 1
        expect(rdv.events.where(event_type: RdvEvent::TYPE_NOTIFICATION_SMS, event_name: "cancelled_by_agent").count).to eq 1
      end

      it "outputs the tokens" do
        expect(subject).to eq({ user.id => token })
      end
    end

    context "starts today or tomorrow" do
      let(:starts_at) { 1.day.from_now }

      it "notifies the users and the other agents (not the author)" do
        expect(Agents::RdvMailer).not_to receive(:rdv_cancelled).with(rdv, agent1, agent1)
        expect(Agents::RdvMailer).to receive(:rdv_cancelled).with(rdv, agent2, agent1)
        expect(Users::RdvMailer).to receive(:rdv_cancelled).with(rdv, user, token)

        subject
        expect(rdv.events.where(event_type: RdvEvent::TYPE_NOTIFICATION_MAIL, event_name: "cancelled_by_agent").count).to eq 1
        expect(rdv.events.where(event_type: RdvEvent::TYPE_NOTIFICATION_SMS, event_name: "cancelled_by_agent").count).to eq 1
      end
    end
  end

  context "cancellation by user" do
    let(:author) { user }
    let(:new_status) { :excused }
    let(:starts_at) { 1.day.from_now }

    it "notifies the user and the agents" do
      expect(Agents::RdvMailer).to receive(:rdv_cancelled).with(rdv, agent1, user)
      expect(Agents::RdvMailer).to receive(:rdv_cancelled).with(rdv, agent2, user)
      expect(Users::RdvMailer).to receive(:rdv_cancelled).with(rdv, user, token)

      subject
      expect(rdv.events.where(event_type: RdvEvent::TYPE_NOTIFICATION_MAIL, event_name: "cancelled_by_user").count).to eq 1
    end
  end
end
