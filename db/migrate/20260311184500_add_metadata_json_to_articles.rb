class AddMetadataJsonToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :metadata_json, :json, null: false, default: {}
  end
end
