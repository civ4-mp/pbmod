#!/usr/bin/python3
# -*- coding: utf-8 -*-
#
# CLI Updater with Python3 (Python2 not available on many systems nowadays).
#

import sys
sys.dont_write_bytecode = True

import zipfile
import os
import os.path
import re
from hashlib import md5

import json
import urllib  # request, parse, error
import urllib.error
import urllib.request

# Define mod name. Required if WITH_MOD_PATH = False
_MOD_NAME_FALLBACK_ = "PBMod_v10"


# Wrap extracted files into extra folder (just for debugging)
EXTRA_NESTING = None
#EXTRA_NESTING = "UPDATE"

class ModUpdater:
    Config_file = "update_config.json"
    Default_config = "update_config.default.json" # Dict or Filename
    """
    Default_config = {
            "update_urls": ["http://localhost:8000/[MODNAME]"],  # Location(s) of 'update.html'
            "visit_url": "http://Your_Mod_homepage",   # Information for User
            "current_version": "__vanilla__",
            "check_at_startup": 0,
        }
    """
    Config = None
    PendingUpdates = []
    __mod_path__ = None
    Info_file = "update_info.json"  # Optional special file in zip's.

    def get_mod_path(self):
        if self.__mod_path__:
            return self.__mod_path__

        # NonCiv4-Variant (CLI-Update). Get path by path to this script.
        (head, tail) = os.path.split(os.path.abspath(__file__))
        subfolder_to_stop = "Assets"
        while len(tail) > 0 and tail != subfolder_to_stop:
            (head, tail) = os.path.split(os.path.abspath(head))

        if tail == subfolder_to_stop:
           self.__mod_path__ = head
        else:
            print("Error: Can not detect path of mod!")
            self.__mod_path__ = os.path.join("/", "dev", "shm", _MOD_NAME_FALLBACK_)

        return self.__mod_path__

    def get_mod_name(self):
        (head, tail) = os.path.split(self.get_mod_path())
        return tail


    def get_config(self):
        if not self.Config:
            self.Config = self.load_config()
        return self.Config

    def get_config_path(self):
        config_path = os.path.join(self.get_config()["mod_path"],
                                   self.Config_file)
        return config_path

    def read_json_dict(self, filename):
        ret = {}
        if os.path.isfile(filename):
            try:
                fp = open(filename, "r")
                ret = dict(json.load(fp))
            finally:
                fp.close()
        return ret

    def load_config(self):
        # Init default config
        if isinstance(self.Default_config, dict):
            config = self.Default_config
        else:
            def_config_path = os.path.join(
                self.get_mod_path(), self.Default_config)
            config = self.read_json_dict(def_config_path)

        config["mod_path"] = self.get_mod_path()  # Ensure correct path

        # Config should be load from mod folder
        # Note: Without CyGame().getModPath() function,
        # this is a chicken-or-the-egg problem
        config_path = os.path.join(config["mod_path"], self.Config_file)

        # Update values from file
        config.update(self.read_json_dict(config_path))
        config["mod_path"] = self.get_mod_path()  # Ensure correct path

        # Replace mod name placeholder
        config["update_urls"] = [ url.replace(
            "[MODNAME]", urllib.parse.quote(self.get_mod_name()))  # Quote for Spaces
            for url in config["update_urls"] ]


        return config

    def write_config(self):
        config_path = self.get_config_path()
        try:
            fp = open(config_path, "w")
            # Note that it's ness. to use the old syntax (integer value)
            # for indent parameter!
            json.dump(self.get_config(), fp, indent=1)
        except:  # Old 2.4 syntax required(!)
            print("(ModUpdater) Write of '%s' failed!" % (config_path,))
            return False
        return True


    def check_for_updates(self):
        config = self.get_config()
        available = [None]  # Dummy for "__vanilla__"
        # installed_names = config.get("installed_updates", [])
        available_names = ["__vanilla__"]

        # Should equals installed_updates[-1]
        current_version = config.get("current_version", "")

        # If users install updates manually, an other update could be
        # the latest installed one. Fetching this value here...
        current_version_by_info_file = \
            self.get_info_json().get("name", "__vanilla__")

        # Try urls and break after first available
        bFoundUrl = False
        for url_prefix in config["update_urls"]:
            url = "%s/%s" % (url_prefix, "updates.html")
            print("(ModUpdater) Fetch '%s'" % (url,))

            updates_html = download_file(url)
            if updates_html is None:
                    continue  # Website lookup failed

            if isinstance(updates_html, bytes):
                updates_html = updates_html.decode('utf-8')

            bFoundUrl = True  # Website lookup ok
            for line in updates_html.splitlines():
                update = self.parse_update_link(line.strip(), url_prefix)
                if not update:
                    continue

                # Skip lines without proper filename
                if not update["name"].endswith(".zip"):
                    continue
                for c in " <>":
                    if c in update["name"]:
                        continue

                available.append(update)
                available_names.append(update["name"])

        if not bFoundUrl:
            return False  # All website lookups failed

        try:
            upos1 = available_names.index(current_version)
        except ValueError:
            upos1 = 0  # "__vanilla__" position
        try:
            upos2 = available_names.index(current_version_by_info_file)
        except ValueError:
            upos2 = 0  # "__vanilla__" position

        if upos2 > upos1+1:
            print("(ModUpdater) WRN: Some updates might be skipped." \
                  "     update_info.json refers to %s" \
                  "     but update_config.json to %s" \
                  % (current_version_by_info_file, current_version))

        self.PendingUpdates = available[max(upos1, upos2)+1:]
        return True  # Website lookup ok

    def parse_update_link(self, line, url_prefix):
        # Remove html comments
        line = re.sub('<!--.*?-->)', '', line)

        # Return dict with founded parameter
        m = re.match('^.*<a[^>]* href="([^"]*)"[^>]*>([^<]*)</a>.*$', line)
        if m:
            name = m.group(2)
            if m.group(1).strip().startswith("http"):
                url = m.group(1)  # Absolute url
            else:
                url = "%s/%s" % (url_prefix, urllib.parse.quote(m.group(1)))

            m_checksum = re.match(
                '^.*<a[^>]* checksum="([^"]*)"[^>]*>([^<]*)</a>.*$', line)
            if m_checksum and m_checksum.group(2) == name:
                checksum = m_checksum.group(1)
                if checksum in ["", "-1"]:
                    checksum = None
            else:
                checksum = None

            # Strip paths, etc
            name = os.path.basename(name)
            name =  re.sub("[^a-zA-Z0-9_. ]", "", name)

            return {"name": name.strip(), "url": url.strip(), "checksum": checksum}
        else:
            return None

    def has_pending_updates(self):
        return (len(self.PendingUpdates) > 0)

    def start_update(self):
        successful = []
        status = {"successful": True, "updates": []}

        # Overwriting of DLLs is not possible at runtime.
        # Renaming currently used file helps.
        # (Not needed in CLI version, but keeping this to get same result as ModUpdater.py.)
        dll_moved = False
        dll_path = os.path.join(self.get_mod_path(), "Assets", "CvGameCoreDLL.dll")
        if os.path.isfile(dll_path):
            dll_path_tmp = dll_path.replace(
                "CvGameCoreDLL.dll", "CvGameCoreDLL.dll.old")
            if os.path.isfile(dll_path_tmp):
                try:
                    os.unlink(dll_path_tmp)
                except Exception as e:
                    print("(ModUpdater) ERR: Unable to remove '%s' Error was %s" %(dll_path_tmp, str(e)))
            try:
                os.rename(dll_path, dll_path_tmp)
            finally:
                dll_moved = True

        try:
            for update in self.PendingUpdates:
                if self.__start_update__(update):
                    successful.append(update)
                else:
                    status["successful"] = False
                    break

        finally:
            # Restore previous DLL if no new one was unzipped
            # (The try-nesting ensure that errors not prevent code from
            # renaming...)
            if dll_moved and not os.path.isfile(dll_path):
                try:
                    os.rename(dll_path_tmp, dll_path)
                finally:
                    dll_moved = False

        for update in successful:
            status["updates"].append({"name": update["name"],
                                      "info": update.get("info", {})
                                      })
            self.PendingUpdates.remove(update)

        return status

    def __start_update__(self, update):
        print("(ModUpdater) Download '%s'" % (update["name"],) )
        config = self.get_config()
        zip_url = update["url"]
        zip_path = os.path.join(config["mod_path"], update["name"])

        # Use checksum to determine if file already preset and
        # should not be downloaded again.
        already_downloaded = False
        if update.get("checksum"):
            md5_sum = get_md5_sum(zip_path)
            if md5_sum == update.get("checksum"):
                print("(ModUpdater) File '%s' is already preset. " \
                      "Skip download of file." % (update["name"],) )
                already_downloaded = True

        # Download file
        if not already_downloaded:
            ret = download_file(zip_url, dest=zip_path)
            if ret is None:
                return False

        # Check checksum of downloaded zip
        if update.get("checksum") and not already_downloaded:
            md5_sum = get_md5_sum(zip_path)
            if md5_sum != update.get("checksum"):
                print("(ModUpdater) ERR: Checksum do not match for '%s'\n Expected: %s\nEvaluated: %s" % (
                    update["name"], update.get("checksum"), md5_sum) )
                return False

        if update["name"].endswith(".zip"):
            print("(ModUpdater) Extract '%s'" % (update["name"],) )

            self.remove_old_info_txt()
            if not self.unzip(zip_path, config["mod_path"]):
                return False

            print("(ModUpdater) Handle meta info of '%s'" % (update["name"],) )
            update["info"] = self.get_info_json()
            if not self.handle_info_json(update["info"]):
                return False

            config["current_version"] = update["name"]
            config["installed_updates"] = config.get(
                "installed_updates", []) +  [update["name"]]
            self.write_config()

        return True


    def unzip(self, zip_path, target_path):

        # Debugging...
        # Uncomment this to write updates into different folder
        if EXTRA_NESTING:
            target_path = os.path.join(target_path, EXTRA_NESTING)

        try:
            zfile = zipfile.ZipFile(zip_path)
            for name in zfile.namelist():
                (dirname, filename) = os.path.split(name)
                if len(filename) == 0:
                    continue  # Ignore lines with folders

                full_path = os.path.join(target_path, dirname)
                print("(ModUpdater) Decompressing %s in %s" % (filename, full_path))
                if not os.path.exists(full_path):  # Nicht notwendig?!
                    os.makedirs(full_path)

                # Do not use full_path as 2nd arg, but relative.
                zfile.extract(name, target_path)

        except Exception as e:
            print("(ModUpdater) Unzipping of %s failed. Error: %s Abort updating" % (
                zip_path, str(e)))
            print("(ModUpdater) Abort updating")
            return False

        return True

    def get_info_json(self):
        info_path = os.path.join(
            self.get_config()["mod_path"],
            self.Info_file)
        info = {}

        # Update values from file
        if os.path.isfile(info_path):
            try:
                fp = open(info_path, "r")
                info.update( dict(json.load(fp)) )
            finally:
                fp.close()

        return info

    def remove_old_info_txt(self):
        info_path = os.path.join(
            self.get_config()["mod_path"],
            self.Info_file)
        if os.path.isfile(info_path):
            try:
                os.unlink(info_path)
            except:
                return False

        return True

    def handle_info_json(self, dInfo):
        print("(ModUpdater) Info file: " + str(dInfo))

        # Check if update meta info provides list of files
        # which should be removed. (Note that they will be removed after
        # the zip was unpacked!)
        lTo_remove = dInfo.get("mod_files_to_remove", [])
        # Use abspath because realpath resovles symbolic links..
        mod_path_abs = os.path.abspath(self.get_mod_path())

        for to_remove in lTo_remove:
            to_remove_slash = to_remove.replace("\\", os.path.sep)
            to_remove_abs = os.path.abspath(os.path.join(
                mod_path_abs, to_remove_slash))
            if not to_remove_abs.startswith(mod_path_abs):
                print("(ModUpdater) WRN: Mod updater skips unlinking of '%s'." % (to_remove,) )
                continue

            if os.path.isfile(to_remove_abs):
                try:
                    os.unlink(to_remove_abs)
                    print("(ModUpdater) Remove '%s'." % (to_remove,) )
                except:
                    print("(ModUpdater) WRN: Mod updater was unable to remove '%s'." % (to_remove,) )

        return True


def get_md5_sum(zip_path):
    if not os.path.isfile(zip_path):
        return None

    md5_sum = "-1"
    try:
        md5_file = open(zip_path, "rb")
        zip_md5 = md5()
        zip_bytes = md5_file.read(1024*1024)
        while len(zip_bytes) > 0:
            zip_md5.update(zip_bytes)
            # Do stuff with byte.
            zip_bytes = md5_file.read(1024*1024)

    except Exception as e:
        print("(ModUpdater) Unable to evaluate md5 of '%s'. Err: %s" %(
            zip_path, str(e)))
        #md5_file.close() # not exists
    else:  # No try-except-finally in Python 2.4
        md5_file.close()
        md5_sum = zip_md5.hexdigest()

    return md5_sum


def download_file(url, *, dest_folder=None, dest=None):
    if dest is None and dest_folder is not None:
        (_, local_filename) = os.path.split(url)
        dest = os.path.join(dest_folder, local_filename)

    if dest is not None:
        try:
            urllib.request.urlretrieve(url, dest)
            return dest
        except Exception as e:
            print("(ModUpdater) Unable to download '%s'. Err: %s" %(url, str(e)))

    else:
        try:
            f = urllib.request.urlopen(url)
            return f.read(10000)
        except Exception as e:
            print("(ModUpdater) Unable to download '%s'. Err: %s" %(url, str(e)))

    return None

if __name__ == "__main__":
    # Check if updates are forced
    bForce = False
    if len(sys.argv) > 1 and sys.argv[1] in ["-f", "--force", "-y", "--yes"]:
        bForce = True

    updater = ModUpdater()
    print("Mod path: {}".format(updater.get_mod_path()))
    updater.check_for_updates()

    if updater.has_pending_updates():
        print("Avaiable updates:")
        for u in updater.PendingUpdates:
            print("  - %s" %(u["name"],) )

        if not bForce:
            print("" \
                  "Press [Enter] to continue installation " \
                  "and [Ctrl+C] to abort.")
            try:
                user_in = sys.stdin.readline()
            except:
                pass
            else:
                bForce = True

        if bForce:
            updater.start_update()

    else:
        print("No pending updates.")
