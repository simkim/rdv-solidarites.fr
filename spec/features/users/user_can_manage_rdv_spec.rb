describe "User can manage their rdvs" do
  let(:rdv) { create(:rdv, starts_at: starts_at) }
  let(:user) { rdv.users.first }

  before do
    login_as(user, scope: :user)
    visit users_rdvs_path
  end

  context "when cancellable" do
    let(:starts_at) { 5.hours.from_now }

    scenario "default", js: true do
      expect(page).to have_content(rdv.motif.name)
      expect(page).to have_selector('li', text: "Annuler le RDV")
      click_link("Annuler le RDV")
      alert = page.driver.browser.switch_to.alert
      alert.accept
      expect(page).to have_selector('.badge', text: "Annulé")
    end
  end

  context "when not cancellable" do
    let(:starts_at) { 4.hours.from_now }

    scenario "default", js: true do
      expect(page).to have_content(rdv.motif.name)
      expect(page).not_to have_selector('li', text: "Annuler le RDV")
      expect(page).to have_selector('li', text: "Ce rendez-vous commence dans moins de 4 heures, il n'est plus annulable en ligne.")
    end
  end
end