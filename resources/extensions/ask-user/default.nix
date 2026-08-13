{ ... }:
{
  title = "Ask user";
  description = "Collect structured choices and freeform answers from the user.";
  homepage = "https://github.com/edlsh/pi-ask-user";
  package = {
    source = "npm:pi-ask-user@0.14.0";
    skills = [ ];
  };
  environment.PI_ASK_USER_DISPLAY_MODE.value = "inline";
}
