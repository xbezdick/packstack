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
Installs and configures OpenStack Horizon
"""

import os
import uuid

from packstack.installer import basedefs
from packstack.installer import exceptions
from packstack.installer import utils

from packstack.modules.documentation import update_params_usage
from packstack.modules.ospluginutils import appendManifestFile
from packstack.modules.ospluginutils import getManifestTemplate
from packstack.modules.ospluginutils import generateSSLCert

# ------------- Horizon Packstack Plugin Initialization --------------

PLUGIN_NAME = "OS-Horizon"
PLUGIN_NAME_COLORED = utils.color_text(PLUGIN_NAME, 'blue')


def initConfig(controller):
    params = [
        {"CMD_OPTION": "os-ssl-cert",
         "USAGE": ("PEM encoded certificate to be used for ssl on the https "
                   "server, leave blank if one should be generated, this "
                   "certificate should not require a passphrase"),
         "PROMPT": ("Enter the path to a PEM encoded certificate to be used "
                    "on the https server, leave blank if one should be "
                    "generated, this certificate should not require "
                    "a passphrase"),
         "OPTION_LIST": [],
         "VALIDATORS": [],
         "DEFAULT_VALUE": '',
         "MASK_INPUT": False,
         "LOOSE_VALIDATION": True,
         "CONF_NAME": "CONFIG_HORIZON_SSL_CERT",
         "USE_DEFAULT": False,
         "NEED_CONFIRM": False,
         "CONDITION": False,
         "DEPRECATES": ['CONFIG_SSL_CERT']},

        {"CMD_OPTION": "os-ssl-key",
         "USAGE": ("SSL keyfile corresponding to the certificate if one was "
                   "entered"),
         "PROMPT": ("Enter the SSL keyfile corresponding to the certificate "
                    "if one was entered"),
         "OPTION_LIST": [],
         "VALIDATORS": [],
         "DEFAULT_VALUE": "",
         "MASK_INPUT": False,
         "LOOSE_VALIDATION": True,
         "CONF_NAME": "CONFIG_HORIZON_SSL_KEY",
         "USE_DEFAULT": False,
         "NEED_CONFIRM": False,
         "CONDITION": False,
         "DEPRECATES": ['CONFIG_SSL_KEY']},

        {"CMD_OPTION": "os-ssl-cachain",
         "USAGE": ("PEM encoded CA certificates from which the certificate "
                   "chain of the server certificate can be assembled."),
         "PROMPT": ("Enter the CA cahin file corresponding to the certificate "
                    "if one was entered"),
         "OPTION_LIST": [],
         "VALIDATORS": [],
         "DEFAULT_VALUE": "",
         "MASK_INPUT": False,
         "LOOSE_VALIDATION": True,
         "CONF_NAME": "CONFIG_HORZION_SSL_CACERT",
         "USE_DEFAULT": False,
         "NEED_CONFIRM": False,
         "CONDITION": False,
         "DEPRECATES": ['CONFIG_SSL_CACHAIN']},
    ]
    update_params_usage(basedefs.PACKSTACK_DOC, params, sectioned=False)
    group = {"GROUP_NAME": "OSSSL",
             "DESCRIPTION": "SSL Config parameters",
             "PRE_CONDITION": "CONFIG_HORIZON_SSL",
             "PRE_CONDITION_MATCH": "y",
             "POST_CONDITION": False,
             "POST_CONDITION_MATCH": True}
    controller.addGroup(group, params)


def initSequences(controller):
    if controller.CONF['CONFIG_HORIZON_INSTALL'] != 'y':
        return

    steps = [
        {'title': 'Adding Horizon manifest entries',
         'functions': [create_manifest]}
    ]
    controller.addSequence("Installing OpenStack Horizon", [], [], steps)


# -------------------------- step functions --------------------------

def create_manifest(config, messages):
    config["CONFIG_HORIZON_SECRET_KEY"] = uuid.uuid4().hex
    horizon_host = config['CONFIG_CONTROLLER_HOST']
    manifestfile = "%s_horizon.pp" % horizon_host

    proto = "http"
    config["CONFIG_HORIZON_PORT"] = 80
    sslmanifestdata = ''
    if config["CONFIG_HORIZON_SSL"]:
        config["CONFIG_HORIZON_PORT"] = 443
        proto = "https"

        # Are we using the users cert/key files
        if config["CONFIG_HORIZON_SSL_CERT"]:
            ssl_cert_file = config["CONFIG_HORIZON_SSL_CERT"]
            ssl_key_file = config["CONFIG_HORIZON_SSL_KEY"]
            ssl_chain_file = config["CONFIG_HORIZON_SSL_CACERT"]

            if not os.path.exists(ssl_cert):
                raise exceptions.ParamValidationError(
                    "The file %s doesn't exist" % ssl_cert)

            if not os.path.exists(ssl_key):
                raise exceptions.ParamValidationError(
                    "The file %s doesn't exist" % ssl_key)

            if not os.path.exists(ssl_chain):
                raise exceptions.ParamValidationError(
                    "The file %s doesn't exist" % ssl_chain)

            # TODO: FIXME: ugly file delivery, we should put this into hiera
            final_cert = open(ssl_cert_file, 'rt').read()
            final_key = open(ssl_key_file, 'rt').read()
            final_cacert = open(ssl_chain_file, 'rt').read()
            server = utils.ScriptRunner(config['CONFIG_CONTROLLER_HOST'])
            server.append("grep -- '{cacert}' {cacert_file} || "
                          "echo '{cacert}' > {cacert_file} ".format(
                              cacert=final_cacert,
                              cacert_file=ssl_chain_file))
            server.append("grep -- '{cert}' {cert_file} || "
                          "echo '{cert}' > {cert_file} ".format(
                              cert=final_cert,
                              cert_file=ssl_cert_file))
            server.append("grep -- '{key}' {key_file} || "
                          "echo '{key}' > {key_file} ".format(
                              key=final_key,
                              key_file=ssl_key_file))
            server.execute()

        else:
            config["CONFIG_HORIZON_SSL_CERT"] = (
                '/etc/pki/tls/certs/ssl_dashboard.crt'
            )
            config["CONFIG_HORIZON_SSL_KEY"] = (
                '/etc/pki/tls/private/ssl_dahsboard.key'
            )
            cacert = config['CONFIG_SSL_CACERT_FILE']
            config["CONFIG_HORIZON_SSL_CACERT"] = cacert
            ssl_key_file = config["CONFIG_HORIZON_SSL_KEY"]
            ssl_cert_file = config["CONFIG_HORIZON_SSL_CERT"]
            ssl_host = config['CONFIG_CONTROLLER_HOST']
            service = 'dashboard'
            generateSSLCert(config, ssl_host, service, ssl_key_file,
                            ssl_cert_file)
            messages.append(
                "%sNOTE%s : A certificate was generated to be used for ssl, "
                "You should change the ssl certificate configured in "
                "/etc/httpd/conf.d/ssl.conf on %s to use a CA signed cert."
                % (utils.COLORS['red'], utils.COLORS['nocolor'], horizon_host))

    config["CONFIG_HORIZON_NEUTRON_LB"] = False
    config["CONFIG_HORIZON_NEUTRON_FW"] = False

    if config['CONFIG_NEUTRON_INSTALL'] == 'y':
        if config["CONFIG_LBAAS_INSTALL"] == 'y':
            config["CONFIG_HORIZON_NEUTRON_LB"] = True
        if config["CONFIG_NEUTRON_FWAAS"] == 'y':
            config["CONFIG_HORIZON_NEUTRON_FW"] = True

    manifestdata = getManifestTemplate("horizon")
    appendManifestFile(manifestfile, manifestdata)

    msg = ("To access the OpenStack Dashboard browse to %s://%s/dashboard .\n"
           "Please, find your login credentials stored in the keystonerc_admin"
           " in your home directory."
           % (proto, config['CONFIG_CONTROLLER_HOST']))
    messages.append(msg)
