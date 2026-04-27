{ ... }:
final: _prev: {
  helium-browser = final.callPackage ../pkgs/helium-browser { };
  python-validity = final.callPackage ../pkgs/python-validity { };
  zjstatus = final.callPackage ../pkgs/zjstatus { };
}
