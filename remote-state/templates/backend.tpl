#!/bin/bash

set -e
%{for config_key, config_value in config ~}
export ${config_key}="${config_value}"
%{endfor ~}
