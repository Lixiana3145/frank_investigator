class CreatePipelineSteps < ActiveRecord::Migration[8.1]
  def change
    create_table :pipeline_steps do |t|
      t.references :investigation, null: false, foreign_key: true
      t.string :name, null: false
      t.string :status, null: false, default: "queued"
      t.integer :attempts_count, null: false, default: 0
      t.datetime :started_at
      t.datetime :finished_at
      t.json :result_json, null: false, default: {}
      t.string :error_class
      t.text :error_message
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end

    add_index :pipeline_steps, [ :investigation_id, :name ], unique: true
    add_index :pipeline_steps, :status
  end
end
