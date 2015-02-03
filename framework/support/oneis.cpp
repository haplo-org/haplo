/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


/*
    Starting utility for the java server, including daemonisation for SMF

    framework/oneis <daemonise> <mode> <config file> <java_executable> [args ...]

    <daemonise> : daemon or utility
    <mode> : 32 or 64

    args are any additional arguments to send to the java executable

*/

// -------------------------------------------------------------------------------------------

#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>

#include <stdio.h>

#include <iostream>
#include <fstream>
#include <vector>
#include <string>

int daemonise();
void wait_for_startup_flag();
int runner(int argc, char *const argv[]);
void substitute_envs(std::string &line);

// Environment variable containing the pathname of the startup flag file
#define ENV_STARTUP_FLAG_FILE "KSTARTUP_FLAG_FILE"


int main(int argc, char *const argv[]) {
    int r = 1;

    try {
        r = runner(argc, argv);
    }
    catch(std::exception &e) {
        fprintf(stderr, "Failed with exception: %s\n", e.what());
        return 1;
    }
    catch(...) {
        fprintf(stderr, "Failed with unknown exception\n");
        return 1;
    }

    return r;
}

int runner(int argc, char *const argv[]) {
    if(argc < 5) {
        fprintf(stderr, "Must specify configuration at very least\n");
        return 1;
    }

    // Parse arguments
    std::string run_how(argv[1]);
    std::string java_mode(argv[2]);
    std::string config_file(argv[3]);
    std::string java_executable(argv[4]);
    int next_arg = 5;
    bool do_daemonisation = false;
    if(run_how == "daemon") {
        do_daemonisation = true;
    } else if(run_how != "utility") {
        fprintf(stderr, "Must specify daemon or utility as first arg\n");
        return 1;
    }
    bool sixty_four_bits = false;
    if(java_mode == "64") {
        sixty_four_bits = true;
    } else if(java_mode != "32") {
        fprintf(stderr, "Must specify 32 or 64 as second arg\n");
        return 1;
    }

    // Basic arguments for executable
    std::vector<std::string> runargs;
    runargs.push_back(java_executable);
    runargs.push_back(sixty_four_bits ? "-d64" : "-d32");

    // Parse the config file
    std::ifstream config(config_file.c_str());
    if(!config.is_open()) {
        fprintf(stderr, "Couldn't open config file\n");
        return 1;
    }
    while(!config.eof()) {
        std::string line;
        getline(config, line);

        if(line.empty() || line[0] == '#') {
            continue;
        }

        substitute_envs(line);

        runargs.push_back(line);
    }
    config.close();

    // Add arguments from command line
    for(int a = next_arg; a < argc; ++a) {
        runargs.push_back(argv[a]);
    }

    // Build argument list in memory
    char **runner_args = (char**)::malloc((runargs.size() + 2) * sizeof(const char *));
    if(runner_args == 0) {
        fprintf(stderr, "Couldn't allocate memory\n");
        return 1;
    }
    for(int a = 0; a < runargs.size(); ++a) {
        runner_args[a] = (char*)runargs[a].c_str();
    }
    runner_args[runargs.size()] = 0;

    if(do_daemonisation) {
        int r = daemonise();
        if(r >= 0) {
            wait_for_startup_flag();
            return 0;
        }
    }

    if(execv(java_executable.c_str(), runner_args) == -1) {
        return 1;
    }

    // Never gets here
    return 0;
}


void substitute_envs(std::string &line) {
    while(true) {
        size_t b = line.find_first_of('{');
        size_t e = line.find_first_of('}');
        if(b == std::string::npos || e == std::string::npos || e <= b) {
            // No more matches, or invalid construction
            return;
        }

        // Get the variable name to subsitute
        std::string name(line, b + 1, e - b - 1);

        // Lookup in environment
        const char *value = getenv(name.c_str());
        if(value == 0) {
            if(name == ENV_STARTUP_FLAG_FILE) {
                // This value is optional -- just use the empty string instead
                value = "";
            } else {
                fprintf(stderr, "Couldn't look up variable '%s' in environment.\n", name.c_str());
                exit(1);
            }
        }

        line.replace(b, e - b + 1, value);
    }
}


int daemonise() {
    switch(fork()) {
    case -1:
        // error
        return 1;
        break;

    default:
        // Success
        return 0;
        break;

    case 0:
        // child
        break;
    }

    // In child

    if(setsid() == -1) {
        return 1;
    }

    // Fork again...
    switch(fork()) {
    case -1:
        // error
        return 1;
        break;

    default:
        // parent
        return 0;
        break;

    case 0:
        // child
        break;
    }

    return -1;
}


void wait_for_startup_flag() {
    const char *flagFilename = ::getenv(ENV_STARTUP_FLAG_FILE);
    if(flagFilename == 0) {
        return;
    }

    while(true) {
        ::sleep(1);

        struct stat st;
        if(::stat(flagFilename, &st) != 0) {
            // Error - don't mind if it's ENOENT or any other error
            break;
        }
    }
}

