# frozen_string_literal: true

ActiveRecord::Schema[7.1].define(version: 20_260_811_120_000) do
  create_table 'action_text_rich_texts', force: :cascade do |t|
    t.string 'name', null: false
    t.text 'body'
    t.string 'record_type', null: false
    t.bigint 'record_id', null: false
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index %w[record_type record_id name], name: 'index_action_text_rich_texts_uniqueness', unique: true
  end

  create_table 'active_storage_attachments', force: :cascade do |t|
    t.string 'name', null: false
    t.string 'record_type', null: false
    t.bigint 'record_id', null: false
    t.bigint 'blob_id', null: false
    t.datetime 'created_at', null: false
    t.index ['blob_id'], name: 'index_active_storage_attachments_on_blob_id'
    t.index %w[record_type record_id name blob_id], name: 'index_active_storage_attachments_uniqueness', unique: true
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
    t.integer 'ruby_llm_model_id', null: false
    t.boolean 'cancelled', default: false, null: false
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['ruby_llm_model_id'], name: 'index_chats_on_ruby_llm_model_id'
  end

  create_table 'messages', force: :cascade do |t|
    t.integer 'chat_id', null: false
    t.string 'role', null: false
    t.text 'content'
    t.string 'model_id'
    t.string 'provider'
    t.text 'thinking_signature'
    t.text 'thinking_text'
    t.json 'content_raw'
    t.json 'citations'
    t.json 'server_tool_calls'
    t.json 'raw_content'
    t.boolean 'cache_until_here', default: false, null: false
    t.string 'finish_reason'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['chat_id'], name: 'index_messages_on_chat_id'
    t.index %w[provider model_id], name: 'index_messages_on_provider_and_model_id'
    t.index ['role'], name: 'index_messages_on_role'
  end

  create_table 'ruby_llm_models', force: :cascade do |t|
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
    t.index ['family'], name: 'index_ruby_llm_models_on_family'
    t.index %w[provider model_id], name: 'index_ruby_llm_models_on_provider_and_model_id', unique: true
    t.index ['provider'], name: 'index_ruby_llm_models_on_provider'
  end

  create_table 'ruby_llm_tool_calls', force: :cascade do |t|
    t.string 'message_type', null: false
    t.integer 'message_id', null: false
    t.string 'result_type'
    t.integer 'result_id'
    t.string 'tool_call_id', null: false
    t.string 'name', null: false
    t.text 'thought_signature'
    t.string 'approval'
    t.json 'arguments', default: {}
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index %w[message_type message_id], name: 'index_ruby_llm_tool_calls_on_message'
    t.index %w[result_type result_id], name: 'index_ruby_llm_tool_calls_on_result'
    t.index ['tool_call_id'], name: 'index_ruby_llm_tool_calls_on_tool_call_id', unique: true
  end

  create_table 'ruby_llm_usage_entries', force: :cascade do |t|
    t.string 'chat_type', null: false
    t.integer 'chat_id', null: false
    t.string 'message_type'
    t.integer 'message_id'
    t.string 'operation', null: false
    t.string 'provider', null: false
    t.string 'model', null: false
    t.string 'status', null: false
    t.integer 'input_tokens'
    t.integer 'output_tokens'
    t.integer 'cache_read_tokens'
    t.integer 'cache_write_tokens'
    t.integer 'thinking_tokens'
    t.decimal 'input_cost', precision: 16, scale: 10
    t.decimal 'output_cost', precision: 16, scale: 10
    t.decimal 'cache_read_cost', precision: 16, scale: 10
    t.decimal 'cache_write_cost', precision: 16, scale: 10
    t.decimal 'thinking_cost', precision: 16, scale: 10
    t.decimal 'total_cost', precision: 16, scale: 10
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index %w[chat_type chat_id], name: 'index_ruby_llm_usage_entries_on_chat'
    t.index %w[message_type message_id], name: 'index_ruby_llm_usage_entries_on_message'
    t.index ['status'], name: 'index_ruby_llm_usage_entries_on_status'
  end

  create_table 'ruby_llm_batches', force: :cascade do |t|
    t.string 'provider_batch_id', null: false
    t.string 'provider', null: false
    t.string 'status'
    t.boolean 'completed', default: false, null: false
    t.string 'chat_type'
    t.string 'batch_protocol'
    t.json 'chat_ids', default: []
    t.json 'request_counts'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index %w[provider provider_batch_id], name: 'index_ruby_llm_batches_on_provider_and_id', unique: true
  end

  create_table 'document_chats', force: :cascade do |t|
    t.integer 'ruby_llm_model_id'
    t.boolean 'cancelled', default: false, null: false
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['ruby_llm_model_id'], name: 'index_document_chats_on_ruby_llm_model_id'
  end

  create_table 'document_messages', force: :cascade do |t|
    t.integer 'document_chat_id'
    t.string 'role'
    t.text 'content'
    t.json 'raw'
    t.string 'model_id'
    t.string 'provider'
    t.integer 'input_tokens'
    t.integer 'output_tokens'
    t.integer 'total_tokens'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['document_chat_id'], name: 'index_document_messages_on_document_chat_id'
  end

  add_foreign_key 'active_storage_attachments', 'active_storage_blobs', column: 'blob_id'
  add_foreign_key 'active_storage_variant_records', 'active_storage_blobs', column: 'blob_id'
  add_foreign_key 'chats', 'ruby_llm_models', column: 'ruby_llm_model_id'
  add_foreign_key 'document_chats', 'ruby_llm_models', column: 'ruby_llm_model_id'
  add_foreign_key 'messages', 'chats'
  add_foreign_key 'document_messages', 'document_chats'
end
