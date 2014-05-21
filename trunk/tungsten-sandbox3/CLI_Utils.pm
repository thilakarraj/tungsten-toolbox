package CLI_Utils;

use strict;
use warnings;
use English '-no_match_vars';
use Getopt::Long;
use Data::Dumper;
use File::Basename;
use Carp;

require Exporter;

our @ISA = qw(Exporter);

our $VERSION = '0.01';
our $VERBOSE = $ENV{CLI_VERBOSE} || $ENV{CLI_DEBUG} || 0;
our $DEBUG = $ENV{CLI_DEBUG} || 0;

my %default_options = (
    # cgi => {
    #        parse   => 'cgi',
    #        value   => 0,
    #        so      => 900,
    #        groups  => ['all', 'cli-admin'],
    #        help    => ['Generate a CGI form to edit this program options ' ]
    #    },
     verbose => {
            parse   => 'verbose',
            value   => 0,
            so      => 910,
            groups  => ['all', 'cli-admin'],
            help    => ['Show more information during installation and help ' ]
        },
     manual => {
            parse   => 'man|manual',
            value   => 0,
            so      => 920,
            groups  => ['all', 'cli-admin'],
            help    => ['Display the program manual' ]
        },
     version => {
            parse   => 'v|version',
            value   => 0,
            so      => 930,
            groups  => ['all', 'cli-admin'],
            help    => ["Show $PROGRAM_NAME version and exit " ]
        },
     display_options => {
            parse   => 'display-options',
            value   => 0,
            so      => 940,
            groups  => ['all', 'cli-admin'],
            help    => ["Show all the options without running the program" ]
        },
      help => {
            parse   => 'h|help',
            value   => 0,
            so      => 1000,
            groups  => ['all', 'cli-admin'],
            help    => ['Display this help' ]
        },
) ;

sub new
{
    my ($class, $params ) = @_;
    my $main_option;
    my $program_name;
    if ($params)
    {
       if (ref($params))
       {
           if (ref($params) eq 'HASH')
            {
                $program_name =  $params->{program_name};
                $main_option  =  $params->{main_option};
                unless ($program_name)
                {
                    $program_name = basename($PROGRAM_NAME);
                }
            }
            elsif (ref($params) eq 'ARRAY')
            {
                $program_name = $params->[0];
                $main_option  = $params->[1];
            }
            else
            {
                die "can't deal with 'params' of this type (@{[ref($params)]})\n";
            }
        }
        else  # scalar
        {
            $program_name = $params;
        }
    }
    my $self = bless {
        parse_options => \%default_options,
        options => {},
        main_option => $main_option,
        program_name => $program_name,
    }, $class;
    return $self;
}

# Returns a nicely formatted set of options for a command with a long list of arguments
sub pretty_command
{
    my ($cmd, $args) = @_;
    my $indent = ' ' x 4;
    $args =~ s{\s+-}{ \\\n$indent-}g;
    return "$cmd$args\n";
}


sub display_options
{
    my ($self) = @_;
    print $self->get_command_line();
}
 

sub write_options
{
    my ($self) = @_;
    my $cli_history = './cookbook/tungsten-cookbook-command-line.history';
    open my $FH, '>>', $cli_history
        or die "can't write to $cli_history($!)\n";
    print $FH "# ", scalar( localtime), "\n";
    $self->{options}{skip_zeroes}=1;
    $self->{options}{skip_defaults}=1;
    print $FH $self->get_command_line(), "\n";
    $self->{options}{skip_zeroes}=0;
    $self->{options}{skip_defaults}=0;
    close $FH;
}
 
sub get_command_line
{
    my ($self) = @_;
    my $parse_options = $self->{parse_options};
    my $options = $self->{options};
    my $command_line = '';
    for my $op (
                sort { $parse_options->{$a}{so} <=> $parse_options->{$b}{so} }
                grep { $parse_options->{$_}{parse}}  keys %{ $parse_options }
               )
    {
        next unless defined $options->{$op};
        next if $op eq 'skip_zeroes';
        next if $op eq 'skip_defaults';
        if ($options->{skip_zeroes})
        {
            next unless $options->{$op};
        }
        if ($options->{skip_defaults})
        {
            next if $options->{$op} && $parse_options->{$op}{value} && ($options->{$op} eq $parse_options->{$op}{value});
        }
        my $param =  $parse_options->{$op}{parse};
        my (undef, $long ) = $param =~ / (?: (\w+) \| )? ([^\|=]+) /x;
        if (ref($options->{$op}) && (ref($options->{$op}) eq 'ARRAY'))
        {
            $command_line .= ' --' . $long . '=' . "@{$options->{$op}}"; 
        }
        else
        {
            if ($parse_options->{$op}{parse} =~ /=/)
            {
                $command_line .= ' --' . $long . '=' . $options->{$op}; 
            }
            else
            {
                $command_line .= ' --' . $long ; 
            }
        }
    }
    # print Dumper $options, $parse_options;
    return pretty_command($PROGRAM_NAME, $command_line);
}

sub process_cgi
{
    my ($self) = @_;
    my $parse_options = $self->{parse_options};
    eval "use CGI qw/:standard *table/; use CGI::Pretty qw(:html3)";
    if ($CHILD_ERROR)
    {
        die "Can't load the CGI module\n";
    }
    my $cgi = CGI::Pretty->new();
    if ($cgi->param())
    {
     
    }
    else
    {
        my $CGI_text = $cgi->header() 
            . $cgi->start_html($self->{program_name} || $PROGRAM_NAME)
            . $cgi->h1($self->{program_name} || $PROGRAM_NAME) 
            . $cgi->start_form()
            . start_table( {border => '1', cellpadding => 5, cellspacing=> 0});
        for my $op (
                sort { $parse_options->{$a}{so} <=> $parse_options->{$b}{so} }
                grep { $parse_options->{$_}{parse}}  keys %{ $parse_options }
               )
        {
           my $parse = $parse_options->{$op}{parse} ;

           my (undef, $long ) = $parse =~ / (?: (\w+) \| )? ([^\|=]+) /x;

           if ($parse_options->{$op}{allowed})
           {
                $CGI_text .= 
                    Tr(td(
                    b($long),
                     p(), 
                    radio_group(
                    -name   =>  $op, 
                    -values =>  [ keys %{ $parse_options->{$op}{allowed} } ],
                    -linebreak => 'true',
                    -default => $self->{options}{$op} || $parse_options->{$op}{value})  
                    ),
                    td(i( join ' ', @{ $parse_options->{$op}{help} } ))
                    )
                . p(); 
           }
           elsif ($parse =~ /=[si]/) 
           {
                $CGI_text   .= 
                            Tr(td(
                            b($long), 
                             ' ',
                            textfield (
                                -name  => $op,
                                -value =>$self->{options}->{$op} || $parse_options->{$op}{value} ) 
                             ),
                             td(i( join ' ', @{ $parse_options->{$op}{help} } ))
                             )
                            . p();
           }
           else 
           {
               $CGI_text .= 
                            Tr(td(
                            checkbox(
                                -name => $op,
                                -label => $long, 
                                -checked => $self->{options}{$op} || $parse_options->{$op}{value} ? '1' : '0',
                                )
                            ),
                            td( i(join ' ', @{ $parse_options->{$op}{help} }) )
                            )
                            . p()
           }
        }
        $CGI_text .=  end_table()
                     . submit(-name => 'submit', -value => "get $self->{program_name} options")
                     . end_form() . hr() . end_html();
        print $CGI_text; 
    } 
    exit;
}


sub getoptions
{
    my ($self) = @_;
    my $parse_options = $self->{parse_options};
    if ($self->{program_name})
    {
        my $prefix = $self->{program_name};
        $prefix =~ s/\W/_/g; 
        for my $op (keys %{ $parse_options} )
        {
            my $key = uc "${prefix}_$op";
            if ($ENV{$key})
            {
                $parse_options->{$op}{value} = $ENV{$key};
            }
        } 
    }
    my %options = map { $_ ,  $parse_options->{$_}{'value'}}  keys %{$parse_options};
    $self->before_parsing();
    GetOptions (
        map { $parse_options->{$_}{parse}, \$options{$_} }    
        grep { $parse_options->{$_}{parse}}  keys %{$parse_options} 
    ) or $self->get_help('');

    $self->{options}= \%options;
    if ($options{cgi})
    {
        $self->process_cgi();
    }
    if ($options{display_options})
    {
        $self->display_options();
        exit 0;
    }
    if ($options{version})
    {
        print $self->get_credits();
        exit 0;
    }
    $VERBOSE = $options{verbose} if $options{verbose};
    $self->get_help() if $options{help};
    get_manual()      if $options{manual};
    $self->after_parsing();
    $self->validate();
    
}

my %options_fields = 
(
    parse       => 1, 
    help        => 1,
    so          => 1,
    value       => 0,
    short       => 0,
    long        => 0,
    must_have   => 0,
    allowed     => 0,
    groups      => 0,
    display     => 0,
    hide        => 0,
    require_version => 0, 
);

sub add_option 
{
    my ($self, $option_name, $option, $replace) = @_;
    unless ($option_name)
    {
        die "Option_name parameter required for add_option\n";
    }

    if ($replace && (! $self->{parse_options}{$option_name}))
    {
        die "Option '$option_name' does not exist: Can't replace.\n";
    }

    if ($self->{parse_options}{$option_name} && (! $replace ))
    {
        die "Option '$option_name' already exists\n";
    }

    unless ($option)
    {
        die "Option parameter required for add_option\n";
    }

    if (! ref($option) or (ref($option) ne 'HASH'))
    {
        die "The 'option' parameter must be a hash ref\n";
    }

    for my $field (keys %{ $option} )
    {
        die "unrecognized field '$field' \n" unless exists $options_fields{$field};
    }

    if ($option->{short} || $option->{long})
    {
        if ($option->{parse})
        {
            die "You must provide either 'parse' or 'short' and 'long', but not both\n";
        }
        $option->{parse} = $option->{short} . '|' . $option->{long};
    }

    for my $field (grep {$options_fields{$_}} keys %options_fields)
    {
        die "field '$field' must exist in option\n" unless exists $option->{$field};
    }

    if (! ref $option->{help})
    {
        $option->{help} = [$option->{help}];
    }

    if (ref($option->{help}) ne 'ARRAY')
    {
        die "the 'help' field in option $option_name must be an array of strings\n";
    }

    if ($option->{allowed})
    {
        my $allowed = $option->{allowed};
        if (ref $allowed )
        {
            if (ref $allowed eq 'ARRAY')
            {
                my %new_allowed;
                for my $f (@{ $option->{allowed} })
                {
                    $new_allowed{$f} = 1;
                }
                $option->{allowed} = \%new_allowed;
            }
        }
        else
        {
            $option->{allowed} = { $allowed => 1};
        }
    }
    my %parse_elements = map { s/=\w+//; $_=> 1} split(/\|/, $option->{parse});
    my @clashing_elements = ();
    for my $opt (keys %{$self->{parse_options}} )
    {
        my @existing_parse_elements = map {s/=\w+//; $_} split(/\|/, $self->{parse_options}{$opt}{parse});
        for my $element (@existing_parse_elements)
        {
            #print "++ $element\n";
            if ( exists $parse_elements{$element})
            {
                push @clashing_elements, 
                "Parsing clash: $option_name:<$option->{parse}>  vs. $opt: <$self->{parse_options}{$opt}{parse}>\n"
                . "Element <$element> from '$option_name' already defined in option '$opt'\n\n";
            }
        }
    }
    if (@clashing_elements)
    {
        for my $item (@clashing_elements)
        {
            warn $item;
        }
        confess "There were clashing items - halting the program\n";
    }
    $self->{parse_options}{$option_name} = $option;
    return $self;
}

sub validate
{
    my ($self) = @_;
    my ($options, $parse_options) = ($self->{options}, $self->{parse_options});
    my @to_be_defined;
    my @not_allowed;
    my $must_exit = 0;
    #
    # Checks that required options are filled
    #
    for my $must ( grep {$parse_options->{$_}->{must_have}} keys %{$parse_options})
    {
        unless (defined $options->{$must})
        {
            my $required = 0;
            if ( ! $self->{main_option} 
                && 
                ref($parse_options->{$must}->{must_have}) 
                && 
                ref($parse_options->{$must}->{must_have}) eq 'ARRAY' )
            {
                warn  "The option $must was defined as depending on a set of values\n"
                    . "(@{$parse_options->{$must}->{must_have}})\n"
                    . "but the 'main_option' label was not set in the constructor\n"; 
                $must_exit = 1;
            }
 
            if ($self->{main_option} 
                && 
                ref($parse_options->{$must}->{must_have}) 
                && 
                ref($parse_options->{$must}->{must_have}) eq 'ARRAY' )
            # 
            # Conditional requirement, with a list of tasks where it is required
            # Using information in the parsing options, this loop determines if 
            # some options must be filled or not.
            {
                for my $task (@{$parse_options->{$must}->{must_have}})
                {
                    # print Dumper($self->{main_option}, $task);
                    if (($self->{main_option}) 
                        &&  
                        ($options->{$self->{main_option}} )
                        &&  
                        ($task eq $options->{$self->{main_option}}))
                    {
                        $required = 1;
                    }
                }
            }
            elsif ($parse_options->{$must}->{must_have} eq '1')
            # unconditional requirement
            {
                $required=1;
            }
            push @to_be_defined, $must if $required;
        }
    }

    #
    # Checks that options requiring given keywords are not using anything different
    #
    for my $option (keys %{$options} ) {
        if (exists $parse_options->{$option}{allowed} && $options->{$option})
        {
            if (ref($options->{$option}) && ref($options->{$option}) eq 'ARRAY')
            {
                my @items;
                for my $item (@{$options->{$option}})
                {
                    if ($item =~ /,/)
                    {
                        push @items,  split /,/, $item;
                    }
                    else
                    {
                        push @items, $item;
                    }
                }
                $options->{$option} = [@items];
                for my $item (@{$options->{$option}})
                {
                    unless (exists $parse_options->{$option}{allowed}{$item})
                    {
                        push @not_allowed, "Not allowed value '$item' for option '$option' - "
                        . " (Choose among: { @{[keys %{$parse_options->{$option}{allowed}} ]} })\n";
                    }
                }
            }
            else
            {
                unless (exists $parse_options->{$option}{allowed}{$options->{$option}})
                {
                    push @not_allowed, "Not allowed value '$options->{$option}' for option '$option' - "
                    . " (Choose among: { @{[keys %{$parse_options->{$option}{allowed}} ]} })\n";
                }
            }
        }
    }
    #
    # Reports errors, if any
    #
    if (@to_be_defined)
    {
        for my $must (@to_be_defined)
        {
            print "Option '$must' must be defined\n"
        }
    }
    if (@not_allowed)
    {
        for my $na (@not_allowed) 
        {
            print $na;
        }
    }
    if (@not_allowed or @to_be_defined or $must_exit)
    {
        exit 1;
    }
}
 
sub get_layout
{
    my $self = (@_);
    return '[options] operation';
}

sub get_help {
    my ($self, $msg) = @_;
    my $parse_options = $self->{parse_options};
    if ($msg) {
        warn "[***] $msg\n\n";
    }

    my $layout = $self->get_layout();
    my $HELP_MSG = q{};
    for my $op (
                sort { $parse_options->{$a}{so} <=> $parse_options->{$b}{so} }
                grep { $parse_options->{$_}{parse}}  keys %{ $parse_options }
               )
    {
        my $param =  $parse_options->{$op}{parse};
        my $param_str = q{    };
        my ($short, $long ) = $param =~ / (?: (\w+) \| )? (\S+) /x;
        if ($short)
        {
            $param_str .= q{-} . $short . q{ };
        }
        $long =~ s/ = s \@? / = name/x;
        $long =~ s/ = i / = number/x;
        $param_str .= q{--} . $long;
        $param_str .= (q{ } x (40 - length($param_str)) );
        my $text_items = $parse_options->{$op}{help};
        my $item_no=0;
        for my $titem (@{$text_items})
        {
            $HELP_MSG .= $param_str . $titem ;
            if (++$item_no == @{$text_items})
            {
                if ($VERBOSE && $parse_options->{$op}{value}) 
                {
                    if (length($parse_options->{$op}{value}) > 40)
                    {
                        $HELP_MSG .= "\n" . q{ } x 40;
                    }
                    $HELP_MSG .=  " ($parse_options->{$op}{value})";
                }
            }
            $HELP_MSG .= "\n";
            $param_str = q{ } x 40;
        }
        if ($VERBOSE && $parse_options->{$op}{must_have}) 
        {
            if (ref$parse_options->{$op}{must_have})
            {
                $HELP_MSG .=  (q{ } x 40) . "(Must have for: @{[join ',', sort @{$parse_options->{$op}{must_have}}  ]})\n"
            }
            else 
            {
                $HELP_MSG .= (q{ } x 40) . '(Must have)' . "\n";
            }
        }
        if ($VERBOSE && $parse_options->{$op}{allowed}) 
        {
            $HELP_MSG .=  (q{ } x 40) . "(Allowed: {@{[join '|', sort keys %{$parse_options->{$op}{allowed}}  ]}})\n"
        }
   }

   print $self->get_credits(),
          "Syntax: $self->{program_name} $layout \n",
          $HELP_MSG;
    exit( defined $msg );
}
 
sub get_manual
{
    my $perldoc = which('perldoc');
    if ($perldoc)
    {
        exec "perldoc $PROGRAM_NAME";
    }
    else
    {
        die  "The 'perldoc' program was not found on this computer.\n"
            ."You need to install it if you want to see the manual\n";
    }
}

#
# Custom implementation of the 'which' command.
# Returns the full path of the command being searched, or NULL on failure.
#
sub which
{
    my ($executable) = @_;
    if ( -x "./$executable" )
    {
        return "./$executable";
    }
    for my $dir ( split /:/, $ENV{PATH} )
    {
        $dir =~ s{/$}{};
        if ( -x "$dir/$executable" )
        {
            return "$dir/$executable";
        }
    }
    return;
}

sub resolveip
{
    my ($hostname) = @_;
    if ($hostname =~ /^\d+\.\d+\.\d+\.\d+$/)
    {
        return $hostname;
    }
    # if resolveip is found, this is the preferred method
    if ($CLI_Utils::VERBOSE)
    {
        print "# Attempting IP resolution using 'resolveip -s $hostname'\n";
    }
    my $resolveip = which('resolveip');
    if ($resolveip)
    {
        my $ip = qx/$resolveip -s $hostname/;
        chomp $ip;
        return $ip;
    }
    # Alternative #1: we parse /etc/host
    if ($CLI_Utils::VERBOSE)
    {
        print"# Attempting IP resolution parsing '/etc/hosts'\n";
    }
     my @lines = slurp('/etc/hosts');
    for my $line (@lines)
    {
        if ($line =~ /^\s*(\d+\.\d+\.\d+\.\d+).*\b$hostname\b/)
        {
            return $1;
        }
    }
    # Alternative #2: we use ping
    if ($CLI_Utils::VERBOSE)
    {
        print "# Attempting IP resolution using 'ping -c1 $hostname'\n";
    }
    my $ping = which('ping');
    if ($ping)
    {
        my $ping_text = qx/$ping -c1 $hostname/;
        if ($ping_text =~ /\((\d+\.\d+\.\d+\.\d+)\)/)
        {
            return $1
        }
    }
    die "Can't resolve IP for $hostname\n";
}


sub get_credits
{
    my ($self) = @_;
    return "Should override 'get_credits'\n";
}   

sub before_parsing
{
    my ($self) = @_;
    # warn "Should override 'before_parsing'\n";
}

sub after_parsing
{
    my ($self) = @_;
    return $self;
}

sub slurp
{
    my ($filename, $options) = @_;
    open my $FH , '<', $filename
        or die "can't open $filename\n";
    my @lines = <$FH>;
    close $FH;
    if ($options && $options->{strip_comments})
    {
        @lines = grep { $_ !~ /^\s*#/ } @lines; 
    }
    if ($options && $options->{strip_blanks})
    {
        @lines = grep { $_ !~ /^\s*$/ } @lines; 
    }
    if (wantarray)
    {
        return @lines;
    }
    else
    {
        my $text ='';
        $text .= $_ for @lines;
        chomp $text;
        return $text;
    }
}

sub get_cfg
{
    my ($fname) = @_;
    my $cfg = slurp($fname);
    $cfg =~ s/:/=>/g;
    $cfg = '$cfg=' . $cfg;
    eval $cfg;
    if ($@)
    {
        die "error evaluating contents of $fname\n";
    }
    return $cfg;
}

sub stringify
{
    my ($label,$s, $parse) = @_;
    if (ref($s))
    {
        my $data=  Data::Dumper->Dump([$s],[$label]);
        $data =~ s/\$($label)/$label/;
        $data =~ s/\n/ /g;
        $data =~ s/\s+/ /g;
        return $data;
    }
    else
    {
        if ($parse =~ /=/)
        {
            return "$label=$s";
        }
        else
        {
            return $label;
        }
    }
}

sub set_more_options
{
    my ($self, $more_options, $original_option) = @_;
    for my $opt (keys %{$more_options})
    {
        unless (exists $self->{parse_options}{$opt})
        {
            die "Error in 'set_more_options': Option $opt is not defined\n";
        }

        $self->{options}{$opt} = $more_options->{$opt};
        $self->{parse_options}{$opt}{value} = $more_options->{$opt};
    }
    if ($self->{options}{verbose})
    {
        $original_option =~ s/_/-/g;
        print "# Option '$original_option' expanded into:\n";
        for my $opt (keys %{$more_options})
        {
            my $full_option= $opt;
            $full_option =~ s/_/-/g;
            print "# --", stringify($full_option,$more_options->{$opt}, $self->{parse_options}{$opt}{parse}), "\n";
        }
        print "\n";
    }
}

sub test_for_version
{
    my ($self, $version) = @_;
    my $version_string= sprintf '%d.%d.%d', $version->{major}, $version->{minor}, $version->{revision};
    for my $option (keys %{ $self->{options} })
    {
        if ( $self->{parse_options}{$option}{require_version} && $self->{options}{$option})
        {
            if ($self->{parse_options}{$option}{require_version} gt $version_string)
            {
                die "option $option requires minimum version $self->{parse_options}{$option}{require_version}\n";
            }
        }
    }
}

1;
# end package CLI_Utils


