# frozen_string_literal: true

describe "welcome pages", js: true do
  it "contact_path page is accessible" do
    expect_page_to_be_axe_clean(contact_path)
  end

  it "accueil_mds_path page is accessible" do
    expect_page_to_be_axe_clean(accueil_mds_path)
  end

  it "mds_path page is accessible" do
    expect_page_to_be_axe_clean(mds_path)
  end

  it "prendre rdv is accessible" do
    territory = create(:territory, departement_number: "75")
    service = create(:service)
    organisation = create(:organisation, territory: territory)
    motif = create(:motif, service: service, organisation: organisation, reservable_online: true)
    lieu = create(:lieu, organisation: organisation)
    create(:plage_ouverture, motifs: [motif], lieu: lieu)

    path = prendre_rdv_path(city_code: "75_119",
                            departement: "75",
                            latitude: "48.887148",
                            longitude: "2.38748",
                            street_ban_id: "75119_4903",
                            address: "152 Avenue Jean Jaurès Paris 75019 Paris")
    expect_page_to_be_axe_clean(path)
  end

  it "new_organisation is accessible" do
    expect_page_to_be_axe_clean(new_organisation_path)
  end

  describe "with available slots" do
    # Nécessite de préciser le département pour le moment,
    # à cause de la recherche par sectorisation (?)
    let(:territory) { create(:territory, departement_number: "75") }
    let(:organisation) { create(:organisation, territory: territory) }
    let(:lieu) { create(:lieu, organisation: organisation) }
    # Double motif pour s'assurer de passer par la page de choix des motifs
    let(:motif) { create(:motif, organisation: organisation, name: "Consultation prénatale") }
    let(:autre_motif) { create(:motif, organisation: organisation) }

    let!(:po_pour_motif) { create(:plage_ouverture, motifs: [motif], lieu: lieu) }
    let!(:po_pour_autre_motif) { create(:plage_ouverture, motifs: [autre_motif], lieu: lieu) }

    it "root path page is accessible" do
      expect_page_to_be_axe_clean(root_path)
    end

    it "root path with a city_code page is accessible" do
      path = root_path(
        departement: 75,
        city_code: 75_056,
        street_ban_id: nil,
        latitude: 48.859,
        longitude: 2.347,
        address: "Paris 75001"
      )
      visit path
      expect(page).to have_content("Sélectionnez le motif de votre RDV")

      expect_page_to_be_axe_clean(path)
    end

    it "root path with a city_code and motif page is accessible" do
      path = root_path(
        motif_name_with_location_type: "Consultation prénatale-public_office",
        address: "Paris 75001",
        city_code: 75_056,
        departement: 75,
        latitude: 48.859,
        longitude: 2.347,
        street_ban_id: nil
      )
      visit path
      expect(page).to have_content("Sélectionnez un lieu de RDV")

      expect_page_to_be_axe_clean(path)
    end

    it "root path with a city_code, motif and lieu page is accessible" do
      path = root_path(
        motif_name_with_location_type: "Consultation prénatale-public_office",
        address: "Paris 75001",
        city_code: 75_056,
        departement: 75,
        latitude: 48.859,
        longitude: 2.347,
        street_ban_id: nil,
        lieu_id: lieu.id,
        date: Time.zone.now
      )

      visit path
      expect(page).to have_content("dimanche")

      expect_page_to_be_axe_clean(path)
    end
  end
end
