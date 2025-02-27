# frozen_string_literal: true

describe TextSearch, type: :concern do
  # Tester les methods du concerns sans un objet des modèles...
  # Peut-être difficile sans activerecord ?

  shared_examples ".search_by_text" do
    it "return findme objects" do
      expect(described_class.search_by_text("findme")).to eq([object])
    end
  end

  shared_examples "#refresh_search_terms" do
    it "update search_terms with combined search terms value" do
      expect do
        object_to_save.refresh_search_terms
      end.to change(object_to_save, :search_terms).from(nil).to("findme")
    end
  end

  shared_examples "#combined_search_terms" do
    it "returns truc truc blabla" do
      expect(object.combined_search_terms).to eq("findme")
    end
  end

  describe(Team) do
    let(:other_object) { create(:team, name: "dont") }
    let(:object) { create(:team, name: "findme") }
    let(:object_to_save) { build(:team, name: "findme") }

    include_examples ".search_by_text"
    include_examples "#refresh_search_terms"
    include_examples "#combined_search_terms"
  end

  describe(User) do
    let(:other_object) { create(:team, name: "dont") }
    let(:object) { create(:team, name: "findme") }
    let(:object_to_save) { build(:team, name: "findme") }

    include_examples "#refresh_search_terms"
    include_examples "#combined_search_terms"

    it "returns users that match with first name" do
      create(:user, first_name: "jean")
      patricia = create(:user, first_name: "patricia")
      expect(described_class.search_by_text("patricia")).to eq([patricia])
    end

    it "returns users that match with partial email" do
      create(:user, email: "jean@moustache.fr")
      patricia = create(:user, email: "patoche@duroy.fr")
      expect(described_class.search_by_text("patoche@dur")).to eq([patricia])
    end

    it "returns users that match with email" do
      create(:user, email: "jean@moustache.fr")
      patricia = create(:user, email: "patoche@duroy.fr")
      expect(described_class.search_by_text("patoche@duroy.fr")).to eq([patricia])
    end

    it "returns users that match with phone_number_formatted" do
      jean = create(:user, phone_number: "01 30 30 04 04")
      create(:user, phone_number: "01 31 34 34 34")
      expect(described_class.search_by_text("+3313030")).to eq([jean])
    end

    it "orders results by relevance" do
      create(:user, first_name: "Marie", last_name: "Petit")
      create(:user, first_name: "Gabrielle", last_name: "Petit")
      create(:user, first_name: "Pauline", last_name: "Martin")
      create(:user, first_name: "Jeanne", last_name: "Durand")
      jean_paul = create(:user, first_name: "Jean-Paul", last_name: "Petit")
      expect(described_class.search_by_text("Jean Paul Petit").count).to eq(5)
      expect(described_class.search_by_text("Jean Paul Petit").first).to eq(jean_paul)
    end

    it "orders results by search terms" do
      marie = create(:user, first_name: "Marie", last_name: "Petit")
      frederic = create(:user, first_name: "Frédéric", last_name: "Petit")
      expect(described_class.search_by_text("Pet")).to eq([frederic, marie])
    end
  end
end
