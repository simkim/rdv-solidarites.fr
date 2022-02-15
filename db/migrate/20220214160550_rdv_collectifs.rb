class RdvCollectifs < ActiveRecord::Migration[6.1]
  def change
    add_column :rdvs, :max_number_of_participants

    # itération possible
    create_table :ateliers do |t| # dans un deuxième temps
      t.belongs_to :motif
      t.belongs_to :lieu

      t.date "first_day", null: false
      t.time "start_time", null: false
      t.text "recurrence"
      t.datetime "recurrence_ends_at"

      t.timestamps
    end

    add_column :rdvs, :atelier_id

    # D'abord ne pas ajouter cette colonne
    # Ensuite l'utiliser juste pour les rdv collectifs
    # Ensuite s'en servir pour les rdv classiques
    # add_column :rdvs_users, :status, :string
  end
end
