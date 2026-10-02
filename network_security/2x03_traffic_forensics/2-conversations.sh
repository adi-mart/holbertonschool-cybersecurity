#!/bin/bash
tshark -r "$1" -z conv,tcp
