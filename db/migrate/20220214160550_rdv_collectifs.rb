class RdvCollectifs < ActiveRecord::Migration[6.1]
  def change
    create_table :creneau_rdv_collectifs do |t|
      t.belongs_to :motif
      t.belongs_to :lieu

      t.date "first_day", null: false
      t.time "start_time", null: false
      t.text "recurrence"
      t.datetime "recurrence_ends_at"

      t.timestamps
    end

    create_table :creneau_rdv_collectifs_agents do |t|
      t.belongs_to :creneau_rdv_collectif
      t.belongs_to :agent
      t.timestamps
    end

    create_table :rdv_collectifs do |t|
      t.belongs_to :creneau_rdv_collectif

      t.timestamps
    end

    add_column :rdvs_users, :rdv_type, :string # "Rdv" ou "RdvCollectif"
  end
end
