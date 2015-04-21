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
Plugin responsible for managing SSL options
"""

from OpenSSL import crypto
from socket import gethostname
from os.path import exists

from packstack.installer import basedefs
from packstack.installer import utils
from packstack.installer import validators

from packstack.modules.documentation import update_params_usage

# ------------- SSL Packstack Plugin Initialization --------------

PLUGIN_NAME = "SSL"
PLUGIN_NAME_COLORED = utils.color_text(PLUGIN_NAME, 'blue')


def initConfig(controller):
    params = {
        "SSL": [
            {"CMD_OPTION": "ssl-cacert-file",
             "PROMPT": ("Enter the filename of the SSL CAcertificate"),
             "OPTION_LIST": [],
             "VALIDATORS": [validators.validate_not_empty],
             "DEFAULT_VALUE": "/etc/pki/tls/certs/selfcert.pem",
             "MASK_INPUT": False,
             "LOOSE_VALIDATION": True,
             "CONF_NAME": "CONFIG_SSL_CACERT_FILE",
             "USE_DEFAULT": False,
             "NEED_CONFIRM": False,
             "CONDITION": False},

            {"CMD_OPTION": "ssl-cacert-key-file",
             "PROMPT": ("Enter the filename of the SSL CAcertificate Key file"),
             "OPTION_LIST": [],
             "VALIDATORS": [validators.validate_not_empty],
             "DEFAULT_VALUE": "/etc/pki/tls/private/selfcert.pem",
             "MASK_INPUT": False,
             "LOOSE_VALIDATION": True,
             "CONF_NAME": "CONFIG_SSL_CACERT_KEY_FILE",
             "USE_DEFAULT": False,
             "NEED_CONFIRM": False,
             "CONDITION": False},

            {"CMD_OPTION": "ssl-cacert-selfsign",
             "PROMPT": "Should packstack use selfsigned CAcert.",
             "OPTION_LIST": ["y", "n"],
             "VALIDATORS": [validators.validate_options],
             "DEFAULT_VALUE": "y",
             "MASK_INPUT": False,
             "LOOSE_VALIDATION": False,
             "CONF_NAME": 'CONFIG_SSL_CACERT_SELFSIGN',
             "USE_DEFAULT": False,
             "NEED_CONFIRM": False,
             "CONDITION": False}
        ],

        "SSL_SELFSIGN": [
            {"CMD_OPTION": "selfsign-cacert-subject-country",
             "PROMPT": "Enter the selfsigned CAcert subject country.",
             "OPTION_LIST": [],
             "VALIDATORS": [validators.validate_not_empty],
             "DEFAULT_VALUE": "--",
             "MASK_INPUT": False,
             "LOOSE_VALIDATION": False,
             "CONF_NAME": 'CONFIG_SELFSIGN_CACERT_SUBJECT_C',
             "USE_DEFAULT": False,
             "NEED_CONFIRM": False,
             "CONDITION": False},

            {"CMD_OPTION": "selfsign-cacert-subject-state",
             "PROMPT": "Enter the selfsigned CAcert subject state.",
             "OPTION_LIST": [],
             "VALIDATORS": [validators.validate_not_empty],
             "DEFAULT_VALUE": "State",
             "MASK_INPUT": False,
             "LOOSE_VALIDATION": False,
             "CONF_NAME": 'CONFIG_SELFSIGN_CACERT_SUBJECT_ST',
             "USE_DEFAULT": False,
             "NEED_CONFIRM": False,
             "CONDITION": False},

            {"CMD_OPTION": "selfsign-cacert-subject-location",
             "PROMPT": "Enter the selfsigned CAcert subject location.",
             "OPTION_LIST": [],
             "VALIDATORS": [validators.validate_not_empty],
             "DEFAULT_VALUE": "City",
             "MASK_INPUT": False,
             "LOOSE_VALIDATION": False,
             "CONF_NAME": 'CONFIG_SELFSIGN_CACERT_SUBJECT_L',
             "USE_DEFAULT": False,
             "NEED_CONFIRM": False,
             "CONDITION": False},

            {"CMD_OPTION": "selfsign-cacert-subject-organization",
             "PROMPT": "Enter the selfsigned CAcert subject organization.",
             "OPTION_LIST": [],
             "VALIDATORS": [validators.validate_not_empty],
             "DEFAULT_VALUE": "openstack",
             "MASK_INPUT": False,
             "LOOSE_VALIDATION": False,
             "CONF_NAME": 'CONFIG_SELFSIGN_CACERT_SUBJECT_O',
             "USE_DEFAULT": False,
             "NEED_CONFIRM": False,
             "CONDITION": False},

            {"CMD_OPTION": "selfsign-cacert-subject-organizational-unit",
             "PROMPT": "Enter the selfsigned CAcert subject organizational unit.",
             "OPTION_LIST": [],
             "VALIDATORS": [validators.validate_not_empty],
             "DEFAULT_VALUE": "packstack",
             "MASK_INPUT": False,
             "LOOSE_VALIDATION": False,
             "CONF_NAME": 'CONFIG_SELFSIGN_CACERT_SUBJECT_OU',
             "USE_DEFAULT": False,
             "NEED_CONFIRM": False,
             "CONDITION": False},

            {"CMD_OPTION": "selfsign-cacert-subject-common-name",
             "PROMPT": "Enter the selfsigned CAcert subject common name.",
             "OPTION_LIST": [],
             "VALIDATORS": [validators.validate_not_empty],
             "DEFAULT_VALUE": gethostname(),
             "MASK_INPUT": False,
             "LOOSE_VALIDATION": False,
             "CONF_NAME": 'CONFIG_SELFSIGN_CACERT_SUBJECT_CN',
             "USE_DEFAULT": False,
             "NEED_CONFIRM": False,
             "CONDITION": False},

            {"CMD_OPTION": "selfsign-cacert-subject-email",
             "PROMPT": "Enter the selfsigned CAcert subject admin email.",
             "OPTION_LIST": [],
             "VALIDATORS": [validators.validate_not_empty],
             "DEFAULT_VALUE": "admin@%s" % gethostname(),
             "MASK_INPUT": False,
             "LOOSE_VALIDATION": False,
             "CONF_NAME": 'CONFIG_SELFSIGN_CACERT_SUBJECT_MAIL',
             "USE_DEFAULT": False,
             "NEED_CONFIRM": False,
             "CONDITION": False},
        ]
    }
    update_params_usage(basedefs.PACKSTACK_DOC, params)

    groups = [
        {"GROUP_NAME": "SSL",
         "DESCRIPTION": "SSL Config parameters",
         "PRE_CONDITION": lambda x: 'yes',
         "PRE_CONDITION_MATCH": "yes",
         "POST_CONDITION": False,
         "POST_CONDITION_MATCH": True},

        {"GROUP_NAME": "SSL_SELFSIGN",
         "DESCRIPTION": "SSL selfsigned CAcert Config parameters",
         "PRE_CONDITION": 'CONFIG_SSL_CACERT_SELFSIGN',
         "PRE_CONDITION_MATCH": "y",
         "POST_CONDITION": False,
         "POST_CONDITION_MATCH": True}
    ]
    for group in groups:
        controller.addGroup(group, params[group['GROUP_NAME']])


def initSequences(controller):
    ssl_steps = [
        {'title': 'Setting up CACERT',
         'functions': [create_self_signed_cert]}
    ]
    controller.addSequence("Setting up SSL", [], [],
                           ssl_steps)


# ------------------------- helper functions -------------------------

def create_self_signed_cert(config, messages):
    """
    OpenSSL wrapper to create selfsigned CA.
    """
    if config['CONFIG_SSL_CACERT_SELFSIGN'] != 'y':
        return

    CERT_FILE = config['CONFIG_SSL_CACERT_FILE']
    KEY_FILE = config['CONFIG_SSL_CACERT_KEY_FILE']
    if not exists(CERT_FILE) or not exists(KEY_FILE):
        # create a key pair
        k = crypto.PKey()
        k.generate_key(crypto.TYPE_RSA, 4096)

        # create a self-signed cert
        mail = config['CONFIG_SELFSIGN_CACERT_SUBJECT_MAIL']
        cert = crypto.X509()
        cert.get_subject().C = config['CONFIG_SELFSIGN_CACERT_SUBJECT_C']
        cert.get_subject().ST = config['CONFIG_SELFSIGN_CACERT_SUBJECT_ST']
        cert.get_subject().L = config['CONFIG_SELFSIGN_CACERT_SUBJECT_L']
        cert.get_subject().O = config['CONFIG_SELFSIGN_CACERT_SUBJECT_O']
        cert.get_subject().OU = config['CONFIG_SELFSIGN_CACERT_SUBJECT_OU']
        cert.get_subject().CN = config['CONFIG_SELFSIGN_CACERT_SUBJECT_CN']
        cert.get_subject().emailAddress = mail
        cert.set_serial_number(1000)
        cert.gmtime_adj_notBefore(0)
        cert.gmtime_adj_notAfter(10 * 365 * 24 * 60 * 60)
        cert.set_issuer(cert.get_subject())
        cert.set_pubkey(k)

        # CA extensions
        cert.add_extensions([
            crypto.X509Extension("basicConstraints".encode('ascii'), False,
                                 "CA:TRUE".encode('ascii')),
            crypto.X509Extension("keyUsage".encode('ascii'), False,
                                 "keyCertSign, cRLSign".encode('ascii')),
            crypto.X509Extension("subjectKeyIdentifier".encode('ascii'), False,
                                 "hash".encode('ascii'),
                                 subject=cert),
        ])

        cert.add_extensions([
            crypto.X509Extension(
                "authorityKeyIdentifier".encode('ascii'), False,
                "keyid:always".encode('ascii'), issuer=cert)
        ])

        cert.sign(k, 'sha1')

        open((CERT_FILE), "wt").write(
            crypto.dump_certificate(crypto.FILETYPE_PEM, cert))
        open((KEY_FILE), "wt").write(
            crypto.dump_privatekey(crypto.FILETYPE_PEM, k))
