class PrefactoryLookup < ActiveRecord::Base
  def self.create_table
    conn = ActiveRecord::Base.connection
    conn.create_table :prefactory_lookups, :force => true do |t|
      t.column :key, :string
      t.column :result_class, :string
      t.column :result_id, :integer
      t.column :result_value, :text
      t.index [:key], :unique => true
    end
  end
end
