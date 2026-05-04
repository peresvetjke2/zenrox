class CreateTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :tasks do |table|
      table.text :body, null: false
      table.string :status, null: false
      table.text :source_text, null: false
      table.string :operation_id, null: false

      table.timestamps
    end

    add_index :tasks, :operation_id, unique: true
    add_index :tasks, :status
  end
end
