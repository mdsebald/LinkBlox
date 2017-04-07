%%% @doc
%%% 
%%% English US Language UI Strings 
%%%
%%% @end

-module(lang_en_us).

-author("Mark Sebald").

-export([
          cmds_map/0,
          strings_map/0
]).


%%
%% Map string to ui command atom
%%
-spec cmds_map() -> list({string(), atom(), string()}).

cmds_map() ->
  [
    {"create",    cmd_create_block,     "<block type name> <new block name>"},
    {"copy",      cmd_copy_block,       "<source block name> <dest block name>"},
    {"rename",    cmd_rename_block,     "<current block name> <new block name>"},
    {"execute",   cmd_execute_block,    "<block name>"},
    {"delete",    cmd_delete_block,     "<block name>"},
    {"disable",   cmd_disable_block,    "<block name>"},
    {"enable",    cmd_enable_block,     "<block name>"},
    {"freeze",    cmd_freeze_block,     "<block name>"},
    {"thaw",      cmd_thaw_block,       "<block name>"},
    {"get",       cmd_get_values,       "<block name>"},
    {"set",       cmd_set_value,        "<block name> <attribute name> <value>"},
    {"link",      cmd_link_blocks,      "<block name> <input name> <block name> <output name>"},
    {"unlink",    cmd_unlink_blocks,    "<block name> <input name>"},
    {"status",    cmd_status,           ""},
    {"valid",     cmd_valid_block_name, "<block name>"},
    {"load",      cmd_load_blocks,      "<file name> | blank"},
    {"save",      cmd_save_blocks,      "<file name> | blank"},
    {"node",      cmd_node,             ""},
    {"nodes",     cmd_nodes,            ""},
    {"connect",   cmd_connect,          "<node name>"},
    {"hosts",     cmd_hosts,            ""},
    {"exit",      cmd_exit,             ""},
    {"help",      cmd_help,             "display help screen"}
  ].


-spec strings_map() -> map().

strings_map() -> #{
  welcome_str => "~n   W E L C O M E  T O  L i n k B l o x !~n~n",
  enter_command_str => "Enter command\n",
  config_str => "Config:~n",
  inputs_str => "Inputs:~n",
  outputs_str => "Outputs:~n",
  self_link_str => "  Link: ~p",
  block_link_str => "  Link: ~p:~p",
  node_link_str => "  Link: ~p:~p:~p",
  reference_str => "  Refs: ~p",
  block_value_set_to_str => "~s:~s Set to: ~s~n",
  enter_block_name => "Enter block-name~n",
  block_exists => "Block: ~s exists~n",
  block_does_not_exist => "Block ~p does not exist~n",
  block_type_created => "Block ~s:~s Created~n",
  dest_block_created => "Dest Block ~s Created~n",
  block_deleted => "Block ~s Deleted~n",
  block_disabled => "Block ~s Disabled~n",
  block_enabled => "Block ~s Enabled~n",
  block_frozen => "Block ~s Frozen~n",
  block_thawed => "Block ~s Thawed~n",
  block_input_linked_to_block_output => "Block Input: ~s:~s Linked to Block Output: ~p~n",
  block_input_unlinked => "Block Input: ~s:~s Unlinked~n",
  block_config_file_loaded => "Block config file: ~s loaded~n",
  block_config_file_saved => "Block config file: ~s saved~n",
  enter_config_file_name => "Enter file name, or press <Enter> for default: 'LinkBloxConfig': ",
  config_file_overwrite_warning => "This will overwrite ~s if the file exists. OK to continue? (Y/N): ",
  node_prompt_str => "Node: ~p~n",
  nodes_prompt_str => "Nodes: ~p~n",
  enter_node_name => "Enter node-name or local~n",
  connecting_to_local_node => "Connecting to local node~n",
  connected_to_node => "Connected to node: ~p~n",
  unable_to_connect_to_node => "Unable to connect to node: ~p~n",
  err_invalid_block_type => "Error: Invalid block type: ~s~n",
  err_block_already_exists => "Error: Block ~s already exists~n",
  err_dest_block_already_exists => "Error: Dest Block ~s already exists~n",
  err_creating_block => "Error: ~p creating block ~s ~n",
  err_creating_block_type => "Error: ~p creating block ~s:~s ~n",
  err_deleting_block => "Error: ~p deleting block ~s~n",
  err_disabling_block => "Error: ~p disabling block ~s~n",
  err_enabling_block => "Error: ~p enabling block ~s~n",
  err_freezing_block => "Error: ~p freezing block ~s~n",
  err_thawing_block => "Error: ~p thawing block ~s~n",
  err_block_not_found => "Error: Block ~s not found~n",
  err_block_value_not_found => "Error: Attribute: ~s does not exist~n",
  err_setting_block_value => "Error: ~p Setting: ~s:~s to ~s~n",
  err_source_block_does_not_exist => "Error: Source Block ~s does not exists~n",
  err_invalid_value_id => "Error: ~s is not a value of block: ~s~n",
  err_retrieving_value => "Error: ~p retrieving value: ~s:~s~n",
  err_invalid_value_id_str => "Error: Invalid Value Id string: ~s~n",
  err_linking_input_to_output => "Error: ~p Linking Input: ~s:~s to Output: ~p~n",
  err_unlinking_input => "Error: ~p Unlinking Input: ~s:~s~n",
  err_converting_to_link => "Error: ~p Converting ~p to a Link~n",
  err_converting_to_input_value_id => "Error: ~p Converting ~s to Input Value ID~n",
  err_too_many_params => "Error: Too many parameters~n",
  unk_cmd_str => "Unknown command string: ~p~n",
  unk_cmd_atom => "Unknown command atom: ~p~n",
  err_unk_result_from_linkblox_api_get_block => "Error: Unkown result from linkblox_api:get_block(): ~p~n",
  err_unk_result_from_linkblox_api_get_value => "Error: Unkown result from linkblox_api:get_value(): ~p~n",
  inv_block_values => "Invalid Block Values. Unable to display. ~n",
  err_loading_block_config_file => "Error: ~p loading block conifg file: ~s~n",
  err_saving_block_config_file => "Error: ~p saving block conifg file: ~s~n",
  err_parsing_cmd_line => "Error: Parsing command: ~s",

  err_invalid_freeze_input_value => "~p Invalid freeze input value: ~p ~n",

  starting_log_server => "Starting log_server, Language Module: ~p~n",
  unknown_log_server_call_msg => "log_server, Unknown call message: ~p~n",
  unknown_log_server_cast_msg => "log_server, Unknown cast message: ~p~n",
  unknown_log_server_info_msg => "log_server, Unknown info message: ~p~n",
  log_server_abnormal_termination => "log_server, Abnormal termination, reason: ~p~n",

  starting_linkblox_block_supervisor => "Starting LinkBlox Block supervisor~n",

  starting_linkblox_API_server => "Starting LinkBlox API server~n",
  stopping_linkblox_API_server => "Stopping LinkBlox API server~n",
  linkblox_API_server_abnormal_termination => "LinkBlox API server, Abnormal Termination: ~p~n",

  starting_node_watcher => "Starting node_watcher~n",
  node_has_connected => "Node ~p has connected~n",
  node_has_disconnected => "Node ~p has disconnected~n",
  node_watcher_received_unexpected_msg => "node_watcher, Received unexpected message: ~p",

  block_server_unknown_call_msg_from => "block_server(~p) Unknown call message: ~p From: ~p~n",
  block_server_unknown_cast_msg => "block_server(~p) Unknown cast message: ~p~n",
  block_server_unknown_info_msg => "block_server, Unknown info message: ~p~n",
  initializing_block => "Initializing: ~p~n",
  err_fetching_value => "Error: ~p fetching value: ~p~n",

  linkblox_api_unknown_call_msg_from => "linkblox_api, Unknown call message: ~p From: ~p~n",
  linkblox_api_unknown_cast_msg => "linkblox_api, Unknown cast message: ~p~n",
  linkblox_api_unknown_info_msg => "linkblox_api, Unknown info message: ~p~n",
  linkblox_api_received_update_for_unknown_block => "linkblox_api, Received update for unknown block: ~p~n",
  linkblox_api_received_unlink_for_unknown_block => "linkblox_api, Recieved unlink for unknown block: ~p~n",

  starting_SSH_CLI_user_interface_on_port_language_module => "Starting SSH CLI User Interface on port: ~p Language Module: ~p~n",

  host_name => "Host name: ~p~n",
  linkblox_startup_complete => "LinkBlox startup complete~n",
  err_starting_linkblox => "Error: ~p starting LinkBlox~n",
  loading_demo_config => "Loading Demo config... ~n",
  invalid_freeze_input_value => "~p Invalid freeze input value: ~p ~n",
  invalid_disable_input_value => "~p Invalid disable input value: ~p ~n",
  negative_exec_interval_value => "~p Negative exec_interval value: ~p ~n",
  invalid_exec_interval_value => "~p Invalid exec_interval value: ~p ~n",
  err_parsing_publish_msg_from_MQTT_broker => "Error: ~p, parsing publish message from MQTT broker~n",
  err_updating_output_on_MQTT_broker_connect_msg => "Error: ~p, updating output on MQTT broker connect message~n",
  err_updating_outputs_on_MQTT_broker_disconnect_msg => "Error: ~p, updating outputs on MQTT broker disconnect message~n",
  block_server_abnormal_termination => "block_server, Abnormal Termination: ~p  Reason: ~p~n",
  err_converting_sensor_values => "Error: ~p converting sensor values~n",
  err_reading_sensor => "Error: ~p reading sensor~n",
  err_reading_sensor_calibration => "Error: ~p reading sensor calibration~n",
  err_configuring_sensor => "Error: ~p configuring sensor~n",
  err_initiating_I2C_address => "Error: ~p intitiating I2C address: ~p~n",
  err_reading_sensor_forced_mode => "Error: ~p reading sensor forced mode~n",
  err_resetting_sensor => "Error: ~p resetting sensor~n",
  err_setting_sensor_config_register => "Error: ~p setting sensor config register~n",
  err_setting_humidity_mode => "Error: ~p setting humidity mode~n",
  err_setting_temperature_pressure_or_read_mode => "Error: ~p setting temperature, pressure, or read modes~n",
  err_is_an_invalid_standby_time_value => "Error: ~p is an invalid standby time value~n",
  err_reading_standby_time_value => "Error: ~p reading standby time value~n",
  err_is_an_invalid_filter_coefficient_value => "Error: ~p is an invalid filter coefficient value~n",
  err_reading_filter_coefficient_value => "Error: ~p reading filter coefficient value~n",
  err_is_an_invalid_humidity_mode_value => "Error: ~p is an invalid humidity mode value~n",
  err_reading_humidity_mode_value => "Error: ~p reading humidity mode value~n",
  err_is_an_invalid_temperature_mode_value => "Error: ~p is an invalid temperature mode value~n",
  err_reading_temperature_mode_value => "Error: ~p reading temperature mode value~n",
  err_is_an_invalid_pressure_mode_value => "Error: ~p is an invalid pressure mode value~n",
  err_reading_pressure_mode_value => "Error: ~p reading pressure mode value~n",
  err_is_an_invalid_read_mode_value_sleep_normal_forced => "Error: ~p is an invalid read mode value (sleep, normal, forced)~n",
  err_reading_read_mode_value => "Error: ~p reading read mode value~n",
  err_waiting_for_sleep_mode => "Error: ~p waiting for sleep mode~n",
  err_setting_forced_read_mode => "Error: ~p setting forced read mode~n",
  err_reading_deg_f_config_value => "Error: ~p reading deg_f config value~n",
  err_reading_temp_offset_config_value => "Error: ~p reading temp_offset config value~n",
  err_reading_inch_merc_config_value => "Error: ~p reading inch_merc config value~n",
  err_reading_press_offset_config_value => "Error: ~p reading press_offset config value~n",
  err_reading_humid_offset_config_value => "Error: ~p reading humid_offset config value~n",

  err_upgrading_block_type_from_ver_to => "Error: ~p upgrading block: ~p type: ~p from ver: ~s to: ~s~n",
  block_type_upgraded_from_ver_to => "Block: ~p type: ~p upgraded from ver: ~s to: ~s~n",

  err_initiating_GPIO_pin => "~p Error: ~p intitiating GPIO pin: ~p~n",
  err_reading_GPIO_pin_number => "~p Error: ~p reading GPIO pin number ~n",
  err_reading_invert_output_value => "Error: ~p reading invert_output value~n",
  err_reading_default_value => "Error: ~p reading default_value~n",
  err_invalid_input_value => "~p Error: invalid input value: ~p~n",
  err_initializing_LCD_driver_I2C_address => "Error: ~p intitializing LCD driver, I2C address: ~p~n",
  err_initializing_LED_driver_I2C_address => "Error: ~p intitializing LED driver, I2C address: ~p~n",
  err_reading_temperature_sensor => "Error: ~p reading temperature sensor~n",
  err_initiating_I2C_address => "Error: ~p intitiating I2C address: ~p~n",
  err_LED_file_does_not_exist => "Error: LED file: ~p does not exist~n",
  err_reading_LED_id => "Error: ~p reading LED ID~n",

  err_saving_block_config_file => "Error: ~p saving block config file: ~s~n",
  block_config_saved_to_file => "Block config saved to file: ~s~n",
  opening_block_values_config_file => "Opening block Values config file: ~p~n",
  err_no_directory_saving_block_config_file => "Error: ~p no directory, saving block config file: ~s~n",
  err_reading_block_config_file => "Error: ~p reading block config file: ~p~n",
  err_creating_block => "Error: ~p creating block ~p~n",
  block_created => "Block ~p created~n",
  err_invalid_config_value => "~p Invalid '~p' config value: ~p~n",
  err_invalid_input_value => "~p Invalid '~p' input value: ~p~n",
  err_invalid_output_value => "~p Invalid '~p' output value: ~p~n",

  deleting_block => "Deleting block: ~p~n",
  reconfiguring_block => "Reconfiguring block: ~p~n",
  creating_type_version => "Creating: ~p Type: ~p Version: ~s~n",
  got_interrupt_from_pin => "Got ~p interrupt from pin# ~p ~n",
  message_from => "Message from ~s: ~p~n",
  mqtt_client_is_connected => "MQTT Client ~p is connected~n",
  mqtt_client_is_disconnected => "Client ~p is disconnected~n",

  err_unrecognized_link => "Error: unrecognized link: ~p~n",
  add_ref_err_doesnt_exist_for_this_block => "add_ref() Error. ~p Doesn't exist for this block~n",
  add_ref_err_invalid_array_index => "add_ref() Error. Invalid array index ~p~n",
  delete_ref_err_doesnt_exist_for_this_block => "delete_ref() Error. ~p Doesn't exist for this block~n",
  delete_ref_err_invalid_array_index => "delete_ref() Error. Invalid array index ~p~n",
  block_input_linked_to_block_output => "Block Input: ~p:~p Linked to Block Output: ~p:~p~n",
  block_input_linked_to_node_block_output => "Block Input: ~p:~p Linked to Block Output: ~p:~p:~p~n",
  block_input_unlinked_from_block_output => "Block Input: ~p:~p Unlinked from Block Output: ~p:~p~n",
  block_input_unlinked_from_node_block_output => "Block Input: ~p:~p Unlinked from Block Output: ~p:~p:~p~n",
  linked_block_does_not_exist => "Linked Block: ~p Does not exist.~n",
  linked_node_block_does_not_exist => "Linked Block: ~p:~p Does not exist.~n",
  unable_to_connect_to_node => "Unable to connect to node: ~p~n",
  unlink_input_linked_block_does_not_exist => "unlink_input(): Linked Block: ~p Does not exist.~n",
  unlink_input_linked_node_block_does_not_exist => "unlink_input(): Linked Block: ~p:~p Does not exist.~n",
  unable_to_connect_to_node => "Unable to connect to node: ~p~n",
  err_unrecognized_link => "Error: unrecognized link: ~p~n",

  started_MQTT_client => "Started MQTT client~n",
  err_starting_MQTT_client => "Error: ~p starting MQTT client~n",
  err_configuring_pub_inputs => "Error: ~p configuring pub inputs~n",
  err_configuring_sub_outputs => "Error: ~p configuring sub outputs~n"

}.
 