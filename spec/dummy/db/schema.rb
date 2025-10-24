# frozen_string_literal: true

# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 20_251_021_170_000) do
  create_table 'active_storage_attachments', force: :cascade do |t|
    t.string 'name', null: false
    t.string 'record_type', null: false
    t.bigint 'record_id', null: false
    t.bigint 'blob_id', null: false
    t.datetime 'created_at', null: false
    t.index ['blob_id'], name: 'index_active_storage_attachments_on_blob_id'
    t.index %w[record_type record_id name blob_id], name: 'index_active_storage_attachments_uniqueness',
                                                    unique: true
  end

  create_table 'active_storage_blobs', force: :cascade do |t|
    t.string 'key', null: false
    t.string 'filename', null: false
    t.string 'content_type'
    t.text 'metadata'
    t.string 'service_name', null: false
    t.bigint 'byte_size', null: false
    t.string 'checksum'
    t.datetime 'created_at', null: false
    t.index ['key'], name: 'index_active_storage_blobs_on_key', unique: true
  end

  create_table 'active_storage_variant_records', force: :cascade do |t|
    t.bigint 'blob_id', null: false
    t.string 'variation_digest', null: false
    t.index %w[blob_id variation_digest], name: 'index_active_storage_variant_records_uniqueness', unique: true
  end

  create_table 'chats', force: :cascade do |t|
    t.integer 'model_id'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['model_id'], name: 'index_chats_on_model_id'
  end

  create_table 'document_chats', force: :cascade do |t|
    t.integer 'model_id'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['model_id'], name: 'index_document_chats_on_model_id'
  end

  create_table 'document_messages', force: :cascade do |t|
    t.integer 'document_chat_id'
    t.string 'role'
    t.text 'content'
    t.json 'raw'
    t.json 'tool_calls'
    t.integer 'model_id'
    t.integer 'input_tokens'
    t.integer 'output_tokens'
    t.integer 'total_tokens'
    t.integer 'tool_call_id'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['document_chat_id'], name: 'index_document_messages_on_document_chat_id'
    t.index ['model_id'], name: 'index_document_messages_on_model_id'
    t.index ['tool_call_id'], name: 'index_document_messages_on_tool_call_id'
  end

  create_table 'messages', force: :cascade do |t|
    t.integer 'chat_id'
    t.string 'role'
    t.text 'content'
    t.integer 'model_id'
    t.integer 'input_tokens'
    t.integer 'output_tokens'
    t.integer 'tool_call_id'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.integer 'cached_tokens'
    t.integer 'cache_creation_tokens'
    t.json 'content_raw'
    t.index ['chat_id'], name: 'index_messages_on_chat_id'
    t.index ['model_id'], name: 'index_messages_on_model_id'
    t.index ['tool_call_id'], name: 'index_messages_on_tool_call_id'
  end

  create_table 'models', force: :cascade do |t|
    t.string 'model_id', null: false
    t.string 'name', null: false
    t.string 'provider', null: false
    t.string 'family'
    t.datetime 'model_created_at'
    t.integer 'context_window'
    t.integer 'max_output_tokens'
    t.date 'knowledge_cutoff'
    t.json 'modalities', default: {}
    t.json 'capabilities', default: []
    t.json 'pricing', default: {}
    t.json 'metadata', default: {}
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['family'], name: 'index_models_on_family'
    t.index %w[provider model_id], name: 'index_models_on_provider_and_model_id', unique: true
    t.index ['provider'], name: 'index_models_on_provider'
  end

  create_table 'tool_calls', force: :cascade do |t|
    t.integer 'message_id'
    t.string 'tool_call_id'
    t.string 'name'
    t.json 'arguments'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['message_id'], name: 'index_tool_calls_on_message_id'
  end

  add_foreign_key 'active_storage_attachments', 'active_storage_blobs', column: 'blob_id'
  add_foreign_key 'active_storage_variant_records', 'active_storage_blobs', column: 'blob_id'
  add_foreign_key 'chats', 'models'
  add_foreign_key 'document_messages', 'document_chats'
  add_foreign_key 'messages', 'models'
end
