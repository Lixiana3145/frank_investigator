class AddHonestHeadlineToInvestigations < ActiveRecord::Migration[8.1]
  def change
    add_column :investigations, :honest_headline, :text
  end
end
