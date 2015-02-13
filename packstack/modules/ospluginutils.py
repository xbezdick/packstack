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

import os
import yaml

from packstack.installer import basedefs
from packstack.installer.setup_controller import Controller

controller = Controller()

PUPPET_DIR = os.path.join(basedefs.DIR_PROJECT_DIR, "puppet")
PUPPET_TEMPLATE_DIR = os.path.join(PUPPET_DIR, "templates")
HIERA_DEFAULTS_YAML = os.path.join(basedefs.HIERADATA_DIR, "defaults.yaml")


class NovaConfig(object):
    """
    Helper class to create puppet manifest entries for nova_config
    """
    def __init__(self):
        self.options = {}

    def addOption(self, n, v):
        self.options[n] = v

    def getManifestEntry(self):
        entry = ""
        if not self.options:
            return entry

        entry += "nova_config{\n"
        for k, v in self.options.items():
            entry += '    "%s": value => "%s";\n' % (k, v)
        entry += "}"
        return entry


class ManifestFiles(object):
    def __init__(self):
        self.filelist = []
        self.data = {}
        self.global_data = None

    # continuous manifest file that have the same marker can be
    # installed in parallel, if on different servers
    def addFile(self, filename, marker, data=''):
        self.data[filename] = self.data.get(filename, '') + '\n' + data
        for f, p in self.filelist:
            if f == filename:
                return

        self.filelist.append((filename, marker))

    def getFiles(self):
        return [f for f in self.filelist]

    def writeManifests(self):
        """
        Write out the manifest data to disk, this should only be called once
        write before the puppet manifests are copied to the various servers
        """
        if not self.global_data:
            with open(os.path.join(PUPPET_TEMPLATE_DIR, "global.pp")) as gfp:
                self.global_data = gfp.read() % controller.CONF
        os.mkdir(basedefs.PUPPET_MANIFEST_DIR, 0o700)
        for fname, data in self.data.items():
            path = os.path.join(basedefs.PUPPET_MANIFEST_DIR, fname)
            fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(fd, 'w') as fp:
                fp.write(self.global_data + data)
manifestfiles = ManifestFiles()


def getManifestTemplate(template_name):
    if not template_name.endswith(".pp"):
        template_name += ".pp"
    with open(os.path.join(PUPPET_TEMPLATE_DIR, template_name)) as fp:
        return fp.read() % controller.CONF


def appendManifestFile(manifest_name, data, marker=''):
    manifestfiles.addFile(manifest_name, marker, data)


def generateHieraDataFile():
    os.mkdir(basedefs.HIERADATA_DIR, 0o700)
    with open(HIERA_DEFAULTS_YAML, 'w') as outfile:
        outfile.write(yaml.dump(controller.CONF,
                                explicit_start=True,
                                default_flow_style=False))


def createFirewallResources(hiera_key, default_value='{}'):
    hiera_function = "hiera('%s', %s)" % (hiera_key, default_value)
    return "create_resources(packstack::firewall, %s)\n\n" % hiera_function


def createIpaHostResources(hiera_key, default_value='{}'):
    hiera_function = "hiera('%s', %s)" % (hiera_key, default_value)
    return "create_resources(ipa::hostadd, %s)\n\n" % hiera_function


def createIpaClientResources(hiera_key, default_value='{}'):
    hiera_function = "hiera('%s', %s)" % (hiera_key, default_value)
    return "create_resources(packstack::ipa_client, %s)\n\n" % hiera_function


def createIpaServiceResources(hiera_key, default_value='{}'):
    hiera_function = "hiera('%s', %s)" % (hiera_key, default_value)
    return "create_resources(ipa::serviceadd, %s)\n\n" % hiera_function


def createIpaCertmongerResources(hiera_key, default_value='{}'):
    hiera_function = "hiera('%s', %s)" % (hiera_key, default_value)
    return ("create_resources(certmonger::request_ipa_cert, %s)\n\n"
            % hiera_function)


def generateIpaServiceManifests(config, ipa_host, ipa_service, ssl_key_file,
                                ssl_cert_file):
    ipa_hosts = config['IPA_HOSTS_DICT']
    ipa_hostname = ipa_hosts.get(ipa_host)
    ipa_server_service = dict()
    key = "freeipa_service_%s_%s" % (ipa_host, ipa_service)
    config_name = "FREEIPA_SERVICE_%s_%s" % (ipa_host, ipa_service)
    ipa_server_service.setdefault(key, {})
    ipa_server_service[key]['name'] = ("%s/%s.packstack@PACKSTACK"
                                       % (ipa_service, ipa_hostname))
    config[config_name] = ipa_server_service
    manifestfile = "%s_ipa.pp" % config['CONFIG_IPA_HOST']
    manifestdata = createIpaServiceResources(config_name)
    appendManifestFile(manifestfile, manifestdata)

    ipa_client_cert = dict()
    key = "freeipa_cert_%s_%s" % (ipa_host, ipa_service)
    config_name = "FREEIPA_CERTIFICATE_%s_%s" % (ipa_host, ipa_service)
    ipa_client_cert.setdefault(key, {})
    ipa_client_cert[key]['name'] = ("openssl-%s/%s.packstack@PACKSTACK"
                                    % (ipa_service, ipa_hostname))
    ipa_client_cert[key]['seclib'] = 'openssl'
    ipa_client_cert[key]['principal'] = ("%s/%s.packstack@PACKSTACK"
                                         % (ipa_service, ipa_hostname))
    ipa_client_cert[key]['key'] = ssl_key_file
    ipa_client_cert[key]['cert'] = ssl_cert_file
    ipa_client_cert[key]['hostname'] = "%s.packstack" % ipa_hostname
    config[config_name] = ipa_client_cert
    manifestfile = "%s_ipa_crts.pp" % ipa_host
    manifestdata = createIpaCertmongerResources(config_name)
    appendManifestFile(manifestfile, manifestdata, 'ipa-crts')


def gethostlist(CONF):
    hosts = []
    for key, value in CONF.items():
        if key.endswith("_HOST"):
            value = value.split('/')[0]
            if value and value not in hosts:
                hosts.append(value)
        if key.endswith("_HOSTS"):
            for host in value.split(","):
                host = host.strip()
                host = host.split('/')[0]
                if host and host not in hosts:
                    hosts.append(host)
    return hosts
