# -*- coding: utf-8 -*-
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""
Installs and configures freeipa
"""

from packstack.installer import validators
from packstack.installer import processors
from packstack.installer import utils
from packstack.installer import output_messages

from packstack.modules.common import filtered_hosts
from packstack.modules.ospluginutils import getManifestTemplate
from packstack.modules.ospluginutils import appendManifestFile
from packstack.modules.ospluginutils import createFirewallResources
from packstack.modules.ospluginutils import createIpaHostResources
from packstack.modules.ospluginutils import createIpaClientResources


PLUGIN_NAME = "IPA"
PLUGIN_NAME_COLORED = utils.color_text(PLUGIN_NAME, 'blue')


def initConfig(controller):
    conf_params = {
        "IPA": [
            {"CMD_OPTION": "ipa-host",
             "USAGE": ("The IP address of the server on which to install "
                       "the IPA service. It's stronly discouraged to "
                       "install IPA on controller node!"),
             "PROMPT": "Enter the IP address of the IPA server",
             "OPTION_LIST": [],
             "VALIDATORS": [validators.validate_ssh],
             "DEFAULT_VALUE": utils.get_localhost_ip(),
             "MASK_INPUT": False,
             "LOOSE_VALIDATION": True,
             "CONF_NAME": "CONFIG_IPA_HOST",
             "USE_DEFAULT": False,
             "NEED_CONFIRM": False,
             "CONDITION": False},

            {"CMD_OPTION": "ipa-dm-password",
             "USAGE": "Password for IPA domain manager",
             "PROMPT": "Enter the password for IPA domain manager",
             "OPTION_LIST": [],
             "VALIDATORS": [validators.validate_not_empty],
             "PROCESSORS": [processors.process_password],
             "DEFAULT_VALUE": "PW_PLACEHOLDER",
             "MASK_INPUT": True,
             "LOOSE_VALIDATION": True,
             "CONF_NAME": "CONFIG_IPA_DM_PASSWORD",
             "USE_DEFAULT": False,
             "NEED_CONFIRM": True,
             "CONDITION": False},

            {"CMD_OPTION": "ipa-admin-password",
             "USAGE": "Password for IPA admin user",
             "PROMPT": "Enter the password for IPA admin user",
             "OPTION_LIST": [],
             "VALIDATORS": [validators.validate_not_empty],
             "PROCESSORS": [processors.process_password],
             "DEFAULT_VALUE": "PW_PLACEHOLDER",
             "MASK_INPUT": True,
             "LOOSE_VALIDATION": True,
             "CONF_NAME": "CONFIG_IPA_ADMIN_PASSWORD",
             "USE_DEFAULT": False,
             "NEED_CONFIRM": True,
             "CONDITION": False},
        ]
    }
    conf_groups = [
        {"GROUP_NAME": "IPA",
         "DESCRIPTION": "IPA Config parameters",
         "PRE_CONDITION": "CONFIG_IPA_INSTALL",
         "PRE_CONDITION_MATCH": "y",
         "POST_CONDITION": False,
         "POST_CONDITION_MATCH": True},
    ]
    for group in conf_groups:
        params = conf_params[group["GROUP_NAME"]]
        controller.addGroup(group, params)


def initSequences(controller):
    config = controller.CONF
    if config['CONFIG_IPA_INSTALL'] != 'y':
        return

    ipa_hosts = dict()
    for host in filtered_hosts(config, exclude=False):
        server = utils.ScriptRunner(host)
        server.append('hostname -s | head -n1')
        retcode, hostname = server.execute()
        if hostname != 'localhost':
            server.append('hostname "$(hostname -s).packstack"')
            server.execute()
            ipa_hosts[host] = str(hostname).strip()
        else:
            raise RuntimeError("localhost is not a valid hostname")
    if len(ipa_hosts.values()) != len(set(ipa_hosts.values())):
        raise RuntimeError("Duplicate hostnames set on hosts")
    # there is no other way to sneak ipa_hosts to other plugins than to put
    # it into config :(
    config['IPA_HOSTS_DICT'] = ipa_hosts

    ipasteps = [
        {'title': 'Adding IPA manifest entries',
         'functions': [create_manifest]}
    ]
    controller.addSequence("Installing IPA", [], [], ipasteps)


# -------------------------- step functions --------------------------

def create_manifest(config, messages):
    # Yeah, ipa is demo and for development, sane user shouldn't use it
    # we need to make sure he notices that.
    msg = output_messages.WARN_IPA_INSTALLED
    messages.append(utils.color_text(msg, 'yellow'))

    ipa_hosts = config['IPA_HOSTS_DICT']

    if config['CONFIG_IPA_HOST'] == config['CONFIG_CONTROLLER_HOST']:
        msg = output_messages.WARN_IPA_CONTROLLER_HORIZON
        messages.append(utils.color_text(msg, 'yellow'))

    ipa_host = ipa_hosts.get(config['CONFIG_IPA_HOST'])
    config['CONFIG_IPA_SERVER_HOSTNAME'] = ipa_host

    manifestfile = "%s_ipa.pp" % config['CONFIG_IPA_HOST']
    manifestdata = getManifestTemplate('ipa_server.pp')

    for ipaddress, hostname in ipa_hosts.items():
        if ipaddress != config['CONFIG_IPA_HOST']:
            ipa_client_details = dict()
            key = "freeipa_host_%s" % hostname
            config_name = "FREEIPA_HOST_%s" % hostname
            ipa_client_details.setdefault(key, {})
            ipa_client_details[key]['name'] = "%s.packstack" % hostname
            ipa_client_details[key]['otp'] = "%s.packstack" % hostname
            config[config_name] = ipa_client_details
            manifestdata += createIpaHostResources(config_name)

    # All hosts should be able to talk to ipa
    for host in filtered_hosts(config, exclude=False):
        fw_details = dict()
        ports = ['80', '443', '389', '636', '88', '464', '53']
        key = "freeipa_tcp_%s" % host
        config_name = "FIREWALL_FREEIPA_TCP_RULES_%s" % host
        fw_details.setdefault(key, {})
        fw_details[key]['service_name'] = "ipa_tcp"
        fw_details[key]['ports'] = ports
        fw_details[key]['chain'] = "INPUT"
        fw_details[key]['proto'] = 'tcp'
        fw_details[key]['host'] = "%s" % host
        config[config_name] = fw_details
        manifestdata += createFirewallResources(config_name)

        fw_details = dict()
        key = "freeipa_udp_%s" % host
        config_name = "FIREWALL_FREEIPA_UDP_RULES_%s" % host
        fw_details.setdefault(key, {})
        fw_details[key]['service_name'] = "ipa_udp"
        fw_details[key]['ports'] = ['88', '464', '53', '123']
        fw_details[key]['chain'] = "INPUT"
        fw_details[key]['proto'] = 'udp'
        fw_details[key]['host'] = "%s" % host
        config[config_name] = fw_details
        manifestdata += createFirewallResources(config_name)

    appendManifestFile(manifestfile, manifestdata, 'ipa-server')

    for ipaddress, hostname in ipa_hosts.items():
        if ipaddress != config['CONFIG_IPA_HOST']:
            admin_install = False
        else:
            admin_install = True
        manifestfile = "%s_ipa_client.pp" % ipaddress
        ipa_client_details = dict()
        key = "freeipa_client_%s" % hostname
        config_name = "FREEIPA_CLIENT_%s" % hostname
        ipa_server_hostname = config['CONFIG_IPA_SERVER_HOSTNAME']
        config['IPA_ADMIN_INSTALL'] = admin_install
        ipa_client_details.setdefault(key, {})
        ipa_client_details[key]['ipa_hostname'] = hostname
        ipa_client_details[key]['ipa_domain'] = 'packstack'
        ipa_client_details[key]['ipa_host_ip'] = ipaddress
        ipa_client_details[key]['ipa_server_hostname'] = ipa_server_hostname
        ipa_client_details[key]['ipa_server_ip'] = config['CONFIG_IPA_HOST']
        ipa_client_details[key]['ipa_admin_install'] = admin_install
        config[config_name] = ipa_client_details
        manifestdata = createIpaClientResources(config_name)
        appendManifestFile(manifestfile, manifestdata, 'ipa-client')

    for ipaddress, hostname in ipa_hosts.items():
        manifestfile = "%s_ipa_crts.pp" % ipaddress
        manifestdata = getManifestTemplate('ipa_certmonger.pp')
        appendManifestFile(manifestfile, manifestdata, 'ipa-crts')
