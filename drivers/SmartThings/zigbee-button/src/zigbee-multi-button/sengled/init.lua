-- Copyright 2022 SmartThings
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

local capabilities = require "st.capabilities"
local constants = require "st.zigbee.constants"
local clusters = require "st.zigbee.zcl.clusters"
local device_management = require "st.zigbee.device_management"
local messages = require "st.zigbee.messages"
local mgmt_bind_resp = require "st.zigbee.zdo.mgmt_bind_response"
local mgmt_bind_req = require "st.zigbee.zdo.mgmt_bind_request"
local utils = require 'st.utils'
local zdo_messages = require "st.zigbee.zdo"
local supported_values = require "zigbee-multi-button.supported_values"
local log = require "log"
local button_utils = require "button_utils"

local SENGLED_MFR_SPECIFIC_CLUSTER = 0xFC10
local SENGLED_MFR_SPECIFIC_COMMAND = 0x00

local PowerConfiguration = clusters.PowerConfiguration


local do_configure = function(self, device)
  device:send(device_management.build_bind_request(device, PowerConfiguration.ID, self.environment_info.hub_zigbee_eui))
--  device:send(device_management.build_bind_request(device, OnOff.ID, self.environment_info.hub_zigbee_eui))
--  device:send(PowerConfiguration.attributes.BatteryVoltage:configure_reporting(device, 30, 21600, 1))
  device:send(PowerConfiguration.attributes.BatteryPercentageRemaining:configure_reporting(device, 30, 21600, 1))
end

local function added_handler(self, device)
  for comp_name, comp in pairs(device.profile.components) do
    if comp_name == "button2" or comp_name == "button3" then
      device:emit_component_event(comp, capabilities.button.supportedButtonValues({"pushed"}))
    else
      device:emit_component_event(comp, capabilities.button.supportedButtonValues({"pushed", "held", "double"}))
    end
    if comp_name == "main" then
      device:emit_component_event(comp, capabilities.button.numberOfButtons({value = 4}))
    else
      device:emit_component_event(comp, capabilities.button.numberOfButtons({value = 1}))
    end
  end
  -- device:send(PowerConfiguration.attributes.BatteryVoltage:read(device))
  device:send(PowerConfiguration.attributes.BatteryPercentageRemaining:read(device))
  device:emit_event(capabilities.button.button.pushed({state_change = false}))
end

local sengled_mfr_specific_command_handler = function(driver, device, zb_rx)
  local cmd = zb_rx.body.zcl_body.body_bytes:byte(1)
  local additional_fields = {
    state_change = true
  }
  local event
  local comp

  if cmd == 0x01 then
    event = capabilities.button.button.pushed(additional_fields)
    comp = device.profile.components["button1"]
    
  elseif cmd == 0x02 then
    event = capabilities.button.button.pushed(additional_fields)
    comp = device.profile.components["button2"]
    
  elseif cmd == 0x03 then
    event = capabilities.button.button.pushed(additional_fields)
    comp = device.profile.components["button3"]
    
  elseif cmd == 0x04 then
    event = capabilities.button.button.pushed(additional_fields)
    comp = device.profile.components["button4"]
    
  elseif cmd == 0x05 then
    event = capabilities.button.button.double(additional_fields)
    comp = device.profile.components["button1"]
    
  elseif cmd == 0x06 then
    event = capabilities.button.button.held(additional_fields)
    comp = device.profile.components["button1"]
    
  elseif cmd == 0x07 then
    event = capabilities.button.button.double(additional_fields)
    comp = device.profile.components["button4"]
    
  elseif cmd == 0x08 then
    event = capabilities.button.button.held(additional_fields)
    comp = device.profile.components["button4"]
    
  else
    log.warn("Invalid button code: " .. cmd)
    return
  end

  if comp ~= nil then
    device:emit_component_event(comp, event)
    device:emit_event(event)
  else
    log.warn("Attempted to emit button event for unknown button: " .. cmd)
  end



end


local battery_perc_attr_handler = function(driver, device, value, zb_rx)
  device:emit_event(capabilities.battery.battery(utils.clamp_value(value.value, 0, 100)))
end

local sengled_device_handler = {
  NAME = "sengled",
  lifecycle_handlers = {
    doConfigure = do_configure,
    added = added_handler
  },
  zigbee_handlers = {
    cluster = {
      [SENGLED_MFR_SPECIFIC_CLUSTER] = {
        -- [SENGLED_MFR_SPECIFIC_COMMAND] = {
          -- [0x01] = button_utils.build_button_handler("button1", capabilities.button.button.pushed),
          -- [0x02] = button_utils.build_button_handler("button2", capabilities.button.button.pushed),
          -- [0x03] = button_utils.build_button_handler("button3", capabilities.button.button.pushed),
          -- [0x04] = button_utils.build_button_handler("button4", capabilities.button.button.pushed),
          -- [0x05] = button_utils.build_button_handler("button1", capabilities.button.button.double),
          -- [0x06] = button_utils.build_button_handler("button1", capabilities.button.button.held),
          -- [0x07] = button_utils.build_button_handler("button4", capabilities.button.button.double),
          -- [0x08] = button_utils.build_button_handler("button4", capabilities.button.button.held)
        -- }
        [SENGLED_MFR_SPECIFIC_COMMAND] = sengled_mfr_specific_command_handler
      }
      
    },
    attr = {
      [PowerConfiguration.ID] = {
        [PowerConfiguration.attributes.BatteryPercentageRemaining.ID] = battery_perc_attr_handler
      }
    }
  },

  can_handle = function(opts, driver, device, ...)
    return device:get_model() == "E1E-G7F"
  end
}

return sengled_device_handler
