@Zigbee @AlertMe @KeyFob
Feature: Zigbee AlertMe Key Fob Driver Test

    These scenarios test the functionality of the Zigbee AlertMe Key Fob driver.

    Background:
        Given the ZB_AlertMe_KeyFob.driver has been initialized

    @basic
    Scenario: Driver reports capabilities to platform.
        When a base:GetAttributes command is placed on the platform bus
        Then the driver should place a base:GetAttributesResponse message on the platform bus
            # NOTE: Button capabilities do not appear in list because they are 'named' instances
            And the message's base:caps attribute list should be [ 'base', 'dev', 'devadv', 'devconn', 'devpow', 'pres' ]
            And the message's dev:devtypehint attribute should be Keyfob
            And the message's devadv:drivername attribute should be ZB_AlertMe_KeyFob
            And the message's devadv:driverversion attribute should be 1.0
        Then both busses should be empty


############################################################
# Driver Lifecycle Tests
############################################################

    @basic @added
    Scenario: Device added
        When the device is added
        Then the capability devpow:source should be BATTERY
            And the capability devpow:linecapable should be false
            And the capability devpow:backupbatterycapable should be false
            And the capability devpow:sourcechanged should be recent
            And the capability but:state.home should be RELEASED
            And the capability but:statechanged.home should be recent
            And the capability but:state.away should be RELEASED
            And the capability but:statechanged.away should be recent
            And the capability pres:presence should be PRESENT
            And the capability pres:usehint should be UNKNOWN
            And the capability pres:person should be UNSET
            And the capability pres:presencechanged should be recent
        # driver should send Mode Change message when added
        Then the driver should send 0x00F0 0xFA
            And with payload 0, 1
        Then protocol bus should be empty

    @basic @connected @timeout @presence
    Scenario: Device connected while Present (while being added)
        Given the capability pres:presence is PRESENT
        When the device is connected
        # driver should send Hello message when connected
        Then the driver should send 0x00F6 0xFC
        Then the driver should set timeout at 10 minutes

    @basic @connected @timeout @presence
    Scenario: Device connected after being Absent
        Given the capability pres:presence is ABSENT
        When the device is connected
        # driver should send Hello message when connected
        Then the driver should send 0x00F6 0xFC
        Then the driver should set timeout at 10 minutes
        Then the capability pres:presence should be PRESENT
            And the capability pres:presencechanged should be recent
        Then the driver should place a base:ValueChange message on the platform bus 
            And the message's pres:presence attribute should be PRESENT

    @basic @disconnected @presence
    Scenario: Device disconnected
        When the device disconnects from the platform
        Then the capability pres:presence should be ABSENT
            And the capability devconn:state should be ONLINE
        Then the driver should place a base:ValueChange message on the platform bus
            And the message's pres:presence attribute should be ABSENT 


############################################################
# General Driver Tests
############################################################

    @basic @name
    Scenario Outline: Make sure driver allows device name to be set 
        When a base:SetAttributes command with the value of dev:name <value> is placed on the platform bus
        Then the platform attribute dev:name should change to <value>

        Examples:
          | value                    | remarks                         |
          | Fob                      | name can be set                 |
          | "Key Fob"                | name with spaces can be set     |
          | "Tom's Keys"             | name with apostrophe can be set |
          | "Bob & Sue's Keys"       | name with ampersand can be set  |


############################################################
# Button Tests
############################################################

    # setAttributes('but')
    @button
    Scenario Outline: Setting Device button attributes
        When a base:SetAttributes command with the value of but:state.<button> <newState> is placed on the platform bus
        Then the capability but:state.<button> should be <newState>

        Examples:
          | button | newState |
          | home   | PRESSED  |
          | home   | RELEASED |
          | away   | PRESSED  |
          | away   | RELEASED |


############################################################
# Presence Tests
############################################################

    # setAttributes('pres')
    @presence
    Scenario Outline: Setting Device presence attribute
        When a base:SetAttributes command with the value of <attributeName> <attributeValue> is placed on the platform bus
        Then the capability <attributeName> should be <attributeValue>

        Examples:
          | attributeName | attributeValue |
          | pres:usehint  | UNKNOWN        |
          | pres:usehint  | PERSON         |
          | pres:usehint  | OTHER          |
          | pres:person   | Jane           |          


############################################################
# AlertMe Heartbeat Tests
############################################################

    @heartbeat @signal
    Scenario Outline: Device sends Heartbeat Message with LQI
        Given the capability devconn:signal is 10
        When the device response with 240 251 
            # status(1byte), timer(4bytes), battery(2bytes), temperature(2bytes), RSSI(1byte), LQI(1byte), Switch Mask(1byte), Switch State(1byte)
            And with payload 8, 0,0,0,0, 0,0, 0,0, 0, <lqi>, 0, 0
            And send to driver
        Then the driver should place a base:ValueChange message on the platform bus
            And the message's devconn:signal attribute should be <signal>
        # should send Stop Polling after heartbeat received
        Then the driver should send 0x00F0 0xFD

        Examples:
          | lqi  | signal | remarks        |
          | 0x00 |      0 |   0/255 =   0% |
          | 0x03 |      1 |   3/255 =   1% |
          | 0x7F |     49 | 127/255 =  49% |
          | 0x80 |     50 | 128/255 =  50% |
          | 0xFF |    100 | 255/255 = 100% |


    @heartbeat @battery
    Scenario Outline: Device sends Heartbeat Message with Battery Level
        Given the capability devpow:battery is 90
        When the device response with 240 251
            # status(1byte), timer(4bytes), battery(2bytes), temperature(2bytes), RSSI(1byte), LQI(1byte), Switch Mask(1byte), Switch State(1byte)
            And with payload 1, 0,0,0,0, <lsb>,<msb>, 0,0, 0, 0, 0, 0
            And send to driver
        Then the driver should place a base:ValueChange message on the platform bus
            And the message's devpow:battery attribute should be <pcnt>
        # should send Stop Polling after heartbeat received
        Then the driver should send 0x00F0 0xFD

        Examples:
          | msb  | lsb  | pcnt | remarks                             |
          | 0x08 | 0x34 |    0 | 2100 mV =   0% of 2.1V - 3.0V range |
          | 0x09 | 0xF6 |   50 | 2550 mV =  50% of 2.1V - 3.0V range |
          | 0x0B | 0xB8 |  100 | 3000 mV = 100% of 2.1V - 3.0V range |
          | 0x07 | 0xD0 |    0 | 2000 mV =   0% of 2.1V - 3.0V range |
          | 0x0C | 0x1C |  100 | 3100 mV = 100% of 2.1V - 3.0V range |



############################################################
# AlertMe Button Cluster Tests
############################################################

    Scenario Outline: Device sends Button Cluster 0xF3 message
        When the device response with 0xF3 <msgId>
            And with payload <buttonId>
            And send to driver
        Then the capability but:state.<buttonName> should be <buttonState>
            And the capability but:statechanged.<buttonName> should be recent

        Examples:
          | msgId | buttonId | buttonName | buttonState | remarks              |
          | 1     | 0        | home       | PRESSED     | Home button PRESSED  |
          | 0     | 0        | home       | RELEASED    | Home button RELEASED |
          | 1     | 1        | away       | PRESSED     | Away button PRESSED  |
          | 0     | 1        | away       | RELEASED    | Away button RELEASED |


############################################################
# AlertMe Hello Response Tests
############################################################

# TODO: Add support for Cluster 246
# 20:47:31.732 [main] WARN  c.i.d.u.c.zb.ZigbeeCommandBuilder - Unsupported Zigbee cluster 246
# 20:47:31.732 [main] DEBUG c.i.d.u.c.zb.ZigbeeCommandBuilder - Look under AlertMe
    @helloResponse
    Scenario: Device sends Hello Response with device info
        When the device response with 0xF6 0xFE
            # Node:0x000A, MfgId:0x0123, DvcType:0x4455, AppRel:0x03, AppVer:1.2, HW Ver:3.4
            And with payload 0x0A,0x00, 0,0,0,0,0,0,0,0,0x23,0x01,0x55,0x44,0x03,0x12,0x04,0x03
            And send to driver
        Then the capability devadv:firmwareVersion should be 1.2.0.3
