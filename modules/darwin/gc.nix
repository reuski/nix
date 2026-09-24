{ ... }:
{
  flake.modules.darwin.gc =
    { ... }:
    {
      nix.gc = {
        automatic = true;
        interval = [
          {
            Weekday = 7;
            Hour = 3;
            Minute = 15;
          }
        ];
        options = "--delete-older-than 7d";
      };

      nix.optimise = {
        automatic = true;
        interval = [
          {
            Weekday = 7;
            Hour = 4;
            Minute = 15;
          }
        ];
      };
    };
}
