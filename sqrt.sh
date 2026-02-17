#!/bin/bash
echo "Enter a number:"
read num
echo "scale=5; sqrt($num)" | bc -l
