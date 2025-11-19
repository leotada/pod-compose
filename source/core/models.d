module core.models;

import std.typecons : Nullable;

@safe:

struct Service {
    string name;
    Nullable!string image;
    Nullable!string buildContext;
    Nullable!string dockerfile;
    Nullable!string target;
    Nullable!string containerName;
    string[] ports;
    string[string] environment;
    string[] volumes;
    string[] command;
    Nullable!string user;
    string[] dependsOn;
    Nullable!string restart;
}

struct ComposeConfig {
    string version_;
    Service[string] services;
    string[string] volumes;
    string[string] networks;
}
