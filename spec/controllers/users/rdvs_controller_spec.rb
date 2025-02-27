# frozen_string_literal: true

RSpec.describe Users::RdvsController, type: :controller do
  render_views

  describe "POST create" do
    subject do
      post :create, params: {
        organisation_id: organisation.id, lieu_id: lieu.id, departement: "12", city_code: "12100", where: "1 rue de la, ville 12345",
        motif_id: motif.id, starts_at: starts_at, organisation_ids: [organisation.id], invitation_token: "44444",
      }
    end

    let!(:organisation) { create(:organisation) }
    let(:user) { create(:user) }
    let(:motif) { create(:motif, organisation: organisation) }
    let(:lieu) { create(:lieu, organisation: organisation) }
    let(:starts_at) { DateTime.parse("2020-10-20 10h30") }
    let(:mock_geo_search) { instance_double(Users::GeoSearch) }
    let(:token) { "12345" }

    before do
      travel_to(Time.zone.local(2019, 7, 20))
      sign_in user

      allow(Users::GeoSearch).to receive(:new)
        .with(departement: "12", city_code: "12100", street_ban_id: nil)
        .and_return(mock_geo_search)
      allow(Users::CreneauSearch).to receive(:creneau_for)
        .with(user: user, starts_at: starts_at, motif: motif, lieu: lieu, geo_search: mock_geo_search)
        .and_return(mock_creneau)
      allow(Notifiers::RdvCreated).to receive(:perform_with)
        .and_return({ user.id => token })
      subject
    end

    describe "when there is an available creneau" do
      let!(:agent) { create(:agent, basic_role_in_organisations: [organisation]) }
      let(:mock_creneau) do
        instance_double(Creneau, agent: agent, motif: motif, lieu: lieu, starts_at: starts_at, duration_in_min: 30)
      end

      it "creates rdv" do
        expect(Rdv.count).to eq(1)
        expect(response).to redirect_to users_rdv_path(Rdv.last, invitation_token: token)
        expect(user.rdvs.last.created_by_user?).to be(true)
      end
    end

    describe "when there is no available creneau" do
      let(:mock_creneau) { nil }

      it "creates rdv" do
        expect(Rdv.count).to eq(0)
        expect(response).to redirect_to prendre_rdv_path(
          departement: "12", service: motif.service_id, motif_name_with_location_type: motif.name_with_location_type,
          address: "1 rue de la, ville 12345", organisation_ids: [organisation.id], invitation_token: "44444",
          city_code: "12100"
        )
        expect(flash[:error]).to eq "Ce créneau n’est plus disponible. Veuillez en sélectionner un autre."
      end
    end
  end

  describe "PUT #cancel" do
    context "when user belongs to rdv" do
      let(:token) { "12345" }
      let(:rdv) { create(:rdv, starts_at: 5.hours.from_now) }

      before do
        allow(RdvUpdater).to receive(:update)
          .and_return(OpenStruct.new(success?: true, rdv_users_tokens_by_user_id: { rdv.users.first.id => token }))
      end

      it "call RdvUpdater.update function" do
        sign_in rdv.users.first
        expect(RdvUpdater).to receive(:update).with(rdv.users.first, rdv, { status: "excused" })
        put :cancel, params: { id: rdv.id }
      end

      it "redirects to the rdv" do
        sign_in rdv.users.first
        put :cancel, params: { id: rdv.id }
        expect(response).to redirect_to users_rdv_path(rdv, invitation_token: token)
      end

      context "when rdv is not cancellable" do
        let(:rdv) { create(:rdv, starts_at: 3.hours.from_now) }

        it "is not authorized" do
          sign_in rdv.users.first

          put :cancel, params: { id: rdv.id }
          expect(response).to redirect_to(users_rdvs_path)
          expect(flash[:error]).to eq("Vous ne pouvez pas effectuer cette action.")
        end
      end
    end

    context "when user does not belongs to rdv" do
      let(:rdv) { create(:rdv, starts_at: 5.hours.from_now) }

      it "raises an error" do
        other_user = create(:user)

        sign_in other_user

        expect do
          put :cancel, params: { id: rdv.id }
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "GET #show" do
    let(:user) { create(:user) }
    let(:rdv) { create(:rdv, users: [user], motif: motif, starts_at: starts_at, created_by: "user") }
    let(:starts_at) { DateTime.parse("2020-10-20 10h30") }
    let(:motif) { build(:motif, reservable_online: true, rdvs_editable_by_user: true, rdvs_cancellable_by_user: true) }

    before do
      travel_to("01/01/2019".to_datetime)
      sign_in user
    end

    it "shows the rdv" do
      get :show, params: { id: rdv.id }

      expect(response).to be_successful
      expect(response.body).to match(/Votre RDV/)
      expect(response.body).to match(/Le mardi 20 octobre 2020/)
      expect(response.body).to match(/Déplacer le RDV/)
      expect(response.body).to match(/Annuler le RDV/)
    end

    context "when the rdv is past" do
      let!(:starts_at) { DateTime.parse("2018-12-31 10h30") }

      it "does show links to edit and cancel" do
        get :show, params: { id: rdv.id }

        expect(response).to be_successful
        expect(response.body).to match(/Votre RDV/)
        expect(response.body).not_to match(/Déplacer le RDV/)
        expect(response.body).not_to match(/Annuler le RDV/)
      end
    end

    context "when the rdv is created by an agent" do
      let(:rdv) { create(:rdv, users: [user], motif: motif, starts_at: starts_at, created_by: "agent") }

      it "does show link to edit" do
        get :show, params: { id: rdv.id }

        expect(response).to be_successful
        expect(response.body).to match(/Votre RDV/)
        expect(response.body).not_to match(/Déplacer le RDV/)
        expect(response.body).to match(/Annuler le RDV/)
      end
    end

    context "when the rdv motif is not reservable_online" do
      let(:motif) { build(:motif, reservable_online: false, rdvs_editable_by_user: true, rdvs_cancellable_by_user: true) }

      it "does show link to edit" do
        get :show, params: { id: rdv.id }

        expect(response).to be_successful
        expect(response.body).to match(/Votre RDV/)
        expect(response.body).not_to match(/Déplacer le RDV/)
        expect(response.body).to match(/Annuler le RDV/)
      end
    end

    context "when the rdv is set as not editable" do
      let(:motif) { build(:motif, reservable_online: true, rdvs_editable_by_user: false, rdvs_cancellable_by_user: true) }

      it "does show link to edit" do
        get :show, params: { id: rdv.id }

        expect(response).to be_successful
        expect(response.body).to match(/Votre RDV/)
        expect(response.body).not_to match(/Déplacer le RDV/)
        expect(response.body).to match(/Annuler le RDV/)
      end
    end

    context "when the rdv is set as not cancellable" do
      let(:motif) { build(:motif, reservable_online: true, rdvs_editable_by_user: true, rdvs_cancellable_by_user: false) }

      it "does show link to edit" do
        get :show, params: { id: rdv.id }

        expect(response).to be_successful
        expect(response.body).to match(/Votre RDV/)
        expect(response.body).to match(/Déplacer le RDV/)
        expect(response.body).not_to match(/Annuler le RDV/)
        expect(response.body).to match(/Ce rendez-vous n'est pas annulable en ligne/)
      end
    end

    context "when the user is not signed in" do
      before do
        sign_out user
      end

      it "redirects to sign in path" do
        get :show, params: { id: rdv.id }

        expect(response).to redirect_to(new_user_session_path)
      end

      context "with a valid invitation token" do
        let!(:invitation_token) do
          user.invite! { |u| u.skip_invitation = true }
          user.raw_invitation_token
        end

        it "redirects to the identity verification form" do
          get :show, params: { id: rdv.id, invitation_token: invitation_token }

          expect(response).to redirect_to(new_users_user_name_initials_verification_path)
        end
      end
    end
  end

  describe "GET #index" do
    subject { get :index }

    let!(:user) { create(:user) }
    let!(:rdv1) { create(:rdv, users: [user], starts_at:  5.days.from_now) }
    let!(:rdv2) { create(:rdv, users: [user], starts_at:  4.days.from_now) }

    context "when signed in" do
      before { sign_in user }

      it "lists the rdvs" do
        subject

        expect(response).to be_successful
        expect(response.body).to include(I18n.l(rdv1.starts_at, format: :human).to_s)
        expect(response.body).to include(I18n.l(rdv2.starts_at, format: :human).to_s)
      end
    end

    context "when not signed in" do
      it "redirects to sign in path" do
        subject

        expect(response).to redirect_to(new_user_session_path)
      end

      context "with a valid invitation token" do
        let!(:invitation_token) do
          user.invite! { |u| u.skip_invitation = true }
          user.raw_invitation_token
        end

        it "is not authorized" do
          get :index, params: { invitation_token: invitation_token }

          expect(response).to redirect_to(root_path)
          expect(flash[:error]).to eq("Vous ne pouvez pas effectuer cette action.")
        end
      end
    end
  end

  describe "GET #creneaux" do
    subject do
      get :creneaux, params: { id: rdv.id }
      rdv.reload
    end

    let(:organisation) { create(:organisation) }
    let(:now) { "01/01/2019 10:00".to_datetime }
    let!(:agent) { create(:agent, basic_role_in_organisations: [organisation]) }
    let!(:lieu) { create(:lieu, address: "10 rue de la Ferronerie 44100 Nantes", organisation: organisation) }
    let!(:motif) { create(:motif, organisation: organisation, max_booking_delay: 2.weeks.to_i) }
    let!(:user) { create(:user) }
    let(:rdv) { create(:rdv, users: [user], starts_at: 5.days.from_now, lieu: lieu, motif: motif, organisation: organisation, created_by: "user") }

    before do
      travel_to(now)
      sign_in user
    end

    context "no creneaux available" do
      before { subject }

      it { expect(assigns(:all_creneaux)).to be_empty }
      it { expect(response.body).to include("Malheureusement, tous les créneaux sont pris.") }
    end

    context "creneaux available" do
      let!(:plage_ouverture) do
        create(:plage_ouverture, :daily, first_day: now + 3.days, start_time: Tod::TimeOfDay.new(10), lieu: lieu, agent: agent, motifs: [motif], organisation: organisation)
      end

      before { subject }

      it { expect(response.body).to include("Voici les créneaux disponibles pour modifier votre rendez-vous du") }
      it { expect(response.body).to include(I18n.l(rdv.starts_at, format: :human).to_s) }
      it { expect(assigns(:date_range)).to eq(3.days.from_now.to_date..9.days.from_now.to_date) }
      it { expect(assigns(:creneaux)).not_to be_empty }
    end

    context "when the rdv cannot be edited" do
      let(:rdv) { create(:rdv, users: [user], starts_at: 2.days.ago, lieu: lieu, motif: motif, organisation: organisation) }

      before { subject }

      it { expect(response).to redirect_to(users_rdvs_path) }
      it { expect(flash[:error]).to eq("Vous ne pouvez pas effectuer cette action.") }
    end
  end

  describe "GET #edit" do
    subject do
      get :edit, params: { id: rdv.id, starts_at: starts_at }
      rdv.reload
    end

    let(:organisation) { create(:organisation) }
    let(:starts_at) { 3.days.from_now }
    let(:now) { "01/01/2019 10:00".to_datetime }
    let!(:agent) { create(:agent, basic_role_in_organisations: [organisation]) }
    let!(:lieu) { create(:lieu, address: "10 rue de la Ferronerie 44100 Nantes", organisation: organisation) }
    let!(:motif) { create(:motif, organisation: organisation) }
    let!(:user) { create(:user) }
    let(:rdv) { create(:rdv, users: [user], starts_at: 5.days.from_now, lieu: lieu, motif: motif, organisation: organisation, created_by: "user") }
    let(:returned_creneau) { Creneau.new }

    before do
      travel_to(now)
      sign_in user

      allow(Users::CreneauSearch).to receive(:creneau_for)
        .with(user: user, starts_at: starts_at, motif: motif, lieu: lieu)
        .and_return(returned_creneau)
    end

    context "creneau is available" do
      before { subject }

      it { expect(response.body).to include("Modification du Rendez-vous") }
      it { expect(response.body).to include("Confirmer le nouveau créneau") }
    end

    context "creneau isn't available" do
      let(:returned_creneau) { nil }

      before { subject }

      it { expect(response).to redirect_to(creneaux_users_rdv_path(rdv)) }
    end

    context "when the rdv is created by an agent" do
      let(:rdv) { create(:rdv, users: [user], starts_at: 5.days.from_now, lieu: lieu, motif: motif, organisation: organisation, created_by: "agent") }

      it "is not authorized" do
        subject
        expect(response).to redirect_to(users_rdvs_path)
        expect(flash[:error]).to eq("Vous ne pouvez pas effectuer cette action.")
      end
    end
  end

  describe "PUT #update" do
    let(:organisation) { create(:organisation) }
    let(:now) { Time.zone.parse("01/01/2019 10:00") }
    let(:starts_at) { 3.days.from_now }
    let(:user) { create(:user) }
    let(:motif) { create(:motif, organisation: organisation) }
    let(:lieu) { create(:lieu, address: "10 rue de la Ferronerie 44100 Nantes", organisation: organisation) }
    let!(:agent) { create(:agent, basic_role_in_organisations: [organisation]) }
    let(:rdv) { create(:rdv, users: [user], starts_at: 5.days.from_now, lieu: lieu, motif: motif, organisation: organisation, created_by: "user") }
    let(:token) { "12345" }

    before do
      travel_to(now)
      sign_in user
      allow(Users::CreneauSearch).to receive(:creneau_for)
        .with(user: user, starts_at: starts_at, motif: motif, lieu: lieu)
        .and_return(returned_creneau)
      allow(Notifiers::RdvDateUpdated).to receive(:perform_with)
        .and_return({ user.id => token })
    end

    context "with an available creneau" do
      let(:returned_creneau) { Creneau.new(starts_at: starts_at, agent: agent) }

      it "respond success and update RDV" do
        put :update, params: { id: rdv.id, starts_at: starts_at, agent_id: agent.id }
        expect(response).to redirect_to(users_rdv_path(rdv, invitation_token: token))
        expect(flash[:success]).to eq("Votre RDV a bien été modifié")
        expect(rdv.reload.starts_at).to eq(starts_at)
        expect(rdv.reload.agent_ids).to eq([agent.id])
      end

      context "when it cannot be updated" do
        before do
          allow_any_instance_of(Rdv).to receive(:update).and_return(false)
        end

        it "redirects to creneaux index" do
          put :update, params: { id: rdv.id, starts_at: starts_at, agent_id: agent.id }
          expect(response).to redirect_to(creneaux_users_rdv_path(rdv))
          expect(flash[:error]).to eq("Le RDV n'a pas pu être modifié")
        end
      end
    end

    context "without an available creneau" do
      let(:returned_creneau) { nil }

      it "redirect to index when not available" do
        put :update, params: { id: rdv.id, starts_at: starts_at, agent_id: agent.id }

        expect(response).to redirect_to(creneaux_users_rdv_path(rdv))
        expect(flash[:alert]).to eq("Ce créneau n'est plus disponible")
      end
    end
  end
end
