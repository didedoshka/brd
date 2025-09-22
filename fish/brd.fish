# brd b|r|br target

function brd
    set type $argv[1]
    set target $argv[2]
    if test $type = "b"; or test $type = "br"
        b $target
        if test $status -ne 0
            return 1
        end
    end

    if test $type = "br"
        echo ""
    end

    if test $type = "r"; or test $type = "br"
        r $target
        return $status
    end
end

function b
    set target $argv[1]
    set directory $(luajit ~/.config/fish/functions/brd_config_helper.lua $target dir)
    set build_command $(luajit ~/.config/fish/functions/brd_config_helper.lua $target build)

    if test -z "$build_command"
        set_color blue
        echo "Build command is not set."
        set_color normal
    else
        set_color blue
        printf "Building in \"%s\".\n" $directory
        set_color normal
        printf "> %s\n" $build_command
        fish -c "cd $directory; $build_command"

        if test $status -ne 0
            set_color red
            echo "Error while building."
            set_color normal
            return 1
        end

        set_color green
        echo "Building finished successfully."
        set_color normal
        return 0
    end
end

function r
    set target $argv[1]
    set directory $(luajit ~/.config/fish/functions/brd_config_helper.lua $target dir)
    set run_command $(luajit ~/.config/fish/functions/brd_config_helper.lua $target run)

    set_color blue
    printf "Running in \"%s\".\n" $directory
    set_color normal
    printf "> %s\n" $run_command
    fish -c "cd $directory; $run_command"

    return $status
end

