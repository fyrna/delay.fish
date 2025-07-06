#!/usr/bin/env fish
# delay.fish - the time feel too fast isn't ?

set VERSION "1.0.0"
set AUTHOR fyrna

# check dependencies
function check_deps
    if not command -v bc &>/dev/null
        echo "Error: bc is required but not installed." >&2
        exit 1
    end
end

### commands
function show_help
    echo "delay.fish v$VERSION - by $AUTHOR

USAGE:
  delay [OPTIONS] <time> [COMMAND...]
  echo \"text\" | delay <time>

OPTIONS:
  -r, --random <min-max> random delay between min and max
  -p, --progress         show progress bar
  -v, --verbose          show debug info
  -h, --help             show this help

TIME UNITS:
  100ms       milliseconds
  2s          seconds
  1m          minutes

EXAMPLE:
  delay -v 1s echo \"boom!\"    # verbose
  cat file.txt | delay 500ms    # pipe mode
  delay -p 5s                   # with progress bar"
end

function parse_time
    set time $argv[1]

    if string match -qr '^([0-9]+)(ms|s|m)?$' $time
        set num (string replace -r '^([0-9]+).*' '$1' $time)
        set unit (string replace -r '^[0-9]+(.*)' '$1' $time)

        switch $unit
            case ms
                echo "scale=3; $num / 1000" | bc -l
            case s
                echo $num
            case m
                echo "$num * 60" | bc -l
            case ''
                echo $num # default to seconds
            case '*'
                echo $num
        end
    else
        echo "Error: Invalid time format '$time'" >&2
        exit 1
    end
end

function random_sleep
    set range $argv[1]

    if not string match -qr '^[0-9]+[ms]?-[0-9]+[ms]?$' $range
        echo "Error: Invalid range format '$range'. Use format like '1-5' or '100ms-2s'" >&2
        exit 1
    end

    set parts (string split '-' $range)
    set min (parse_time $parts[1])
    set max (parse_time $parts[2])

    # check if min <= max
    if test (echo "$min > $max" | bc -l) -eq 1
        echo "Error: min ($min) should be <= max ($max)" >&2
        exit 1
    end

    set diff (echo "$max - $min" | bc -l)
    set random_num (random 0 32767)
    set random_delay (echo "scale=3; $min + $diff * $random_num / 32767" | bc -l)
    echo $random_delay
end

function show_progress
    set sleep_time $argv[1]
    set steps 20
    set step_interval (echo "scale=3; $sleep_time / $steps" | bc -l)
    set spinner ⣾ ⢿ ⡿ ⣟ ⣯ ⣷ ⣾ ⣽
    set spin_len (count $spinner)

    echo "[delay] Progress with $sleep_time seconds delay:"

    for i in (seq 0 (math $steps - 1))
        sleep $step_interval

        # Move cursor to start of line and clear it
        echo -ne "\r\033[K[delay] Progress: ["

        # Draw completed parts
        for j in (seq 0 $i)
            echo -ne "\033[1;32m█\033[0m"
        end

        # Draw remaining spaces
        for j in (seq (math $i + 1) (math $steps - 1))
            echo -ne " "
        end

        # Show percentage and spinner
        set percent (math "($i + 1) * 100 / $steps")
        set spin_idx (math "($i % $spin_len) + 1")
        set spin_char $spinner[$spin_idx]
        echo -ne "] $percent% ($spin_char)"
    end
    echo -e "\n[delay] Complete!"
end

function main
    check_deps

    # initialize variables
    set random_range ""
    set verbose false
    set show_progress_bar false
    set sleep_time 0

    # parse arguments
    set i 1
    while test $i -le (count $argv)
        switch $argv[$i]
            case -r --random
                if test (math $i + 1) -le (count $argv)
                    set random_range $argv[(math $i + 1)]
                    set i (math $i + 2)
                else
                    echo "Error: --random requires a range argument" >&2
                    exit 1
                end

            case -p --progress
                set show_progress_bar true
                set i (math $i + 1)

            case -v --verbose
                set verbose true
                set i (math $i + 1)

            case -h --help
                show_help
                exit 0

            case --
                set i (math $i + 1)
                break

            case '-*'
                echo "Error: Unknown option '$argv[$i]'" >&2
                show_help
                exit 1

            case '*'
                break
        end
    end

    # get remaining arguments
    set remaining_args $argv[$i..-1]

    # calculate sleep time
    if test -n "$random_range"
        set sleep_time (random_sleep $random_range)
        if $verbose
            echo "[delay] Random sleep: $sleep_time seconds"
        end
    else if test (count $remaining_args) -ge 1
        set sleep_time (parse_time $remaining_args[1])
        set remaining_args $remaining_args[2..-1]
    else
        echo "Error: No time specified" >&2
        show_help
        exit 1
    end

    # check if we're in pipe mode
    if not isatty stdin
        if $verbose
            echo "[delay] Pipe mode: waiting $sleep_time seconds"
        end

        if $show_progress_bar
            show_progress $sleep_time
        else
            sleep $sleep_time
        end

        cat
        exit
    end

    # normal
    if test (count $remaining_args) -eq 0
        if $verbose
            echo "[delay] No command provided (sleeping only)"
        end

        if $show_progress_bar
            show_progress $sleep_time
        else
            sleep $sleep_time
        end
        exit
    end

    if $verbose
        echo "[delay] Will execute after $sleep_time seconds: $remaining_args"
    end

    if $show_progress_bar
        show_progress $sleep_time
    else
        sleep $sleep_time
    end

    # execute command
    eval $remaining_args
end

main $argv
