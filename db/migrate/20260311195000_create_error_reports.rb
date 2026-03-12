class CreateErrorReports < ActiveRecord::Migration[8.1]
  def change
    create_table :error_reports do |t|
      t.string :error_class, null: false
      t.text :message, null: false
      t.text :backtrace
      t.string :severity, default: "error", null: false
      t.string :source
      t.json :context, default: {}, null: false
      t.string :fingerprint, null: false
      t.integer :occurrences_count, default: 1, null: false
      t.datetime :first_occurred_at, null: false
      t.datetime :last_occurred_at, null: false
      t.timestamps

      t.index :fingerprint, unique: true
      t.index :last_occurred_at
      t.index :severity
    end
  end
end
