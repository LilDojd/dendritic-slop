{ ... }:
{
  title = "Web access";
  description = "Add web search, URL fetching, source checking, and local document extraction.";
  homepage = "https://github.com/nicobailon/pi-web-access";
  defaultEnable = false;
  package = {
    # renovate: datasource=npm depName=pi-web-access
    source = "npm:pi-web-access@0.22.0";
  };
}
