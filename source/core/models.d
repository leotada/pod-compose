module core.models;

import std.typecons : Nullable;

@safe:

// --- Helper Structs ---

struct HealthCheck
{
    string[] test;
    Nullable!string interval;
    Nullable!string timeout;
    Nullable!int retries;
    Nullable!string startPeriod;
    Nullable!string startInterval;
    Nullable!bool disable;
}

struct Logging
{
    Nullable!string driver;
    string[string] options;
}

struct Build
{
    Nullable!string context;
    Nullable!string dockerfile;
    string[string] args;
    string[] cacheFrom;
    string[string] labels;
    Nullable!string network;
    Nullable!string shmSize;
    Nullable!string target;
    string[] secrets;
    string[] tags;
    string[] platforms;
}

struct ResourcesLimits
{
    Nullable!float cpus;
    Nullable!string memory;
    Nullable!int pids;
}

struct ResourcesReservations
{
    Nullable!float cpus;
    Nullable!string memory;
    // devices and generic_resources omitted for brevity/complexity for now, can be added later
}

struct Resources
{
    ResourcesLimits limits;
    ResourcesReservations reservations;
}

struct RestartPolicy
{
    Nullable!string condition;
    Nullable!string delay;
    Nullable!int maxAttempts;
    Nullable!string window;
}

struct UpdateConfig
{
    Nullable!int parallelism;
    Nullable!string delay;
    Nullable!string failureAction;
    Nullable!string monitor;
    Nullable!float maxFailureRatio;
    Nullable!string order;
}

struct RollbackConfig
{
    Nullable!int parallelism;
    Nullable!string delay;
    Nullable!string failureAction;
    Nullable!string monitor;
    Nullable!float maxFailureRatio;
    Nullable!string order;
}

struct Deploy
{
    Nullable!string mode;
    Nullable!int replicas;
    string[string] labels;
    UpdateConfig updateConfig;
    RollbackConfig rollbackConfig;
    RestartPolicy restartPolicy;
    Resources resources;
    Nullable!string endpointMode;
    // placement omitted for now
}

struct Port
{
    Nullable!string target;
    Nullable!string published;
    Nullable!string protocol;
    Nullable!string mode;
    Nullable!string hostIp;
}

struct ServiceVolume
{
    Nullable!string type;
    Nullable!string source;
    Nullable!string target;
    Nullable!bool readOnly;
    string[string] bind; // bind options
    string[string] volume; // volume options
    string[string] tmpfs; // tmpfs options
    Nullable!string consistency;
}

struct ServiceSecret
{
    Nullable!string source;
    Nullable!string target;
    Nullable!string uid;
    Nullable!string gid;
    Nullable!int mode;
}

struct ServiceConfig
{
    Nullable!string source;
    Nullable!string target;
    Nullable!string uid;
    Nullable!string gid;
    Nullable!int mode;
}

struct NetworkAttachment
{
    string name;
    string[] aliases;
    Nullable!string ipv4Address;
    Nullable!string ipv6Address;
}

struct ServiceDependency
{
    string condition;
    Nullable!bool restart;
}

// --- Top Level Structs ---

struct TopLevelNetwork
{
    Nullable!string driver;
    string[string] driverOpts;
    Nullable!bool attachable;
    Nullable!bool enableIpv6;
    Nullable!bool internal;
    string[string] labels;
    Nullable!bool external;
    Nullable!string name;
    // ipam omitted for now
}

struct TopLevelVolume
{
    Nullable!string driver;
    string[string] driverOpts;
    Nullable!bool external;
    string[string] labels;
    Nullable!string name;
}

struct TopLevelConfig
{
    Nullable!string file;
    Nullable!bool external;
    string[string] labels;
    Nullable!string name;
    Nullable!string content; // For inline configs
}

struct TopLevelSecret
{
    Nullable!string file;
    Nullable!bool external;
    string[string] labels;
    Nullable!string name;
    Nullable!string environment;
}

struct Service
{
    string name;

    // Basic
    Nullable!string image;
    Nullable!string containerName;
    Nullable!string hostname;
    Nullable!string domainname;
    Nullable!string macAddress;
    Nullable!string workingDir;
    Nullable!string user;
    string[] profiles;

    // Build
    Nullable!Build build;

    // Ports
    Port[] ports;

    // Networks
    NetworkAttachment[string] networks; // keyed by network name

    // Volumes
    ServiceVolume[] volumes;

    // Environment
    string[string] environment;
    string[] envFile;

    // Lifecycle
    Nullable!string restart;
    ServiceDependency[string] dependsOn;
    Nullable!bool init;
    Nullable!string stopGracePeriod;
    Nullable!string stopSignal;

    // Healthcheck
    Nullable!HealthCheck healthcheck;

    // Logging
    Nullable!Logging logging;

    // Resources (v2/v3 compat)
    Nullable!int cpuCount;
    Nullable!float cpuPercent;
    Nullable!int cpuShares;
    Nullable!string cpuPeriod;
    Nullable!string cpuQuota;
    Nullable!float cpus;
    Nullable!string cpuset;
    Nullable!string memLimit;
    Nullable!string memReservation;
    Nullable!int memSwappiness;
    Nullable!string memswapLimit;
    Nullable!string shmSize;
    Nullable!int pidsLimit;
    // ulimits omitted for complexity, can be string or map

    // Security
    string[] capAdd;
    string[] capDrop;
    string[] securityOpt;
    Nullable!bool privileged;
    Nullable!bool readOnly;
    string[] devices;
    string[] deviceCgroupRules;
    string[] groupAdd;
    Nullable!string isolation;
    Nullable!string usernsMode;

    // Networking
    string[] dns;
    string[] dnsOpt;
    string[] dnsSearch;
    string[] extraHosts;
    string[] expose;
    Nullable!string networkMode;

    // Configs/Secrets
    ServiceConfig[] configs;
    ServiceSecret[] secrets;

    // Deployment
    Nullable!Deploy deploy;

    // Other
    string[string] labels;
    string[string] sysctls;
    string[] tmpfs;
    Nullable!bool stdinOpen;
    Nullable!bool tty;
    string[] command;
    string[] entrypoint;
}

struct ComposeConfig
{
    string version_;
    Nullable!string name;
    Service[string] services;
    TopLevelNetwork[string] networks;
    TopLevelVolume[string] volumes;
    TopLevelConfig[string] configs;
    TopLevelSecret[string] secrets;
}
