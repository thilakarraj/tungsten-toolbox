#!/usr/bin/perl

use strict;
use warnings;
use English '-no_match_vars';
use Data::Dumper;

my $syntax = "Syntax: $PROGRAM_NAME CSV_name destination_directory";
my $csv_fname = shift
    or die "No filename passed ($syntax)\n";

my $destination_dir = shift
    or die "No destination directory passed ($syntax)\n";

unless ( -d $destination_dir)
{
    die "Destination directory $destination_dir not found\n";
}

my $db_name ='';
my $db_table = '';
my $seqno = 0;

if ($csv_fname =~ m{/([^/]+)/([^/]+)-(\d+)\.csv$} )
{
    $db_name    = $1;
    $db_table   = $2;
    $seqno      = $3;
    # print "<$db_name><$db_table><$seqno>\n"; exit;
}
else
{
    die     "CSV file name does not match the pattern\n"
        .   "Expected: /path/schema/table-###.csv\n";
}

my %tools = (
    mysql   =>   'mysql',
    sqlite  =>   'sqlite3',
);

for my $tool (keys %tools)
{
    my $full_path =  qx(which $tools{$tool});
    chomp $full_path;
    # print "<$full_path>\n";
    if ( -x  $full_path)
    {
        $tools{$tool} = $full_path;
    }
    else
    {
        die "Program $tool not found in \$PATH\n";
    }
}

my $db_user     = $ENV{DB_USER}     || '';
my $db_password = $ENV{DB_PASSWORD} || '';
my $db_host     = $ENV{DB_HOST}     || '';
my $db_port     = $ENV{DB_PORT}     || '';
my $my_cnf      = $ENV{MY_CNF}      || "$ENV{HOME}/.my.cnf" ;

if ($db_user && $db_password)
{
    $my_cnf = '/tmp/mytmp.cnf';
    open my $FH, '>', $my_cnf
        or die "Can't open $my_cnf ($!)\n";
    print $FH   "[client]\n",
                "user=$db_user\n",
                "password=$db_password\n";
    if ($db_host)
    {
        print $FH "host=$db_host\n";
    }
    if ($db_port)
    {
        print $FH "port=$db_port\n";
    }
    close $FH;
}
elsif ( ! -f $my_cnf)
{
    die "This program requires a .my.cnf file (Looking for $my_cnf. None found)\n";
}

my $first_line = 1;
my @header;
my @CDC;
open my $CSV, '<', $csv_fname
    or die "Can't open $csv_fname ($!)\n";
my $separator = $ENV{CSV_SEPARATOR} || '\|';
while (my $line = readline($CSV))
{
    chomp $line;
    if ($first_line)
    {
        @header = split /$separator/, $line;
        $first_line = 0;
    }
    else
    {
        my @row = split /$separator/, $line;
        for my $col (@row)
        {
            $col =~ s/^"//;
            $col =~ s/"$//;
        }
        push @CDC, [@row];
    }
}

close $CSV;

# print Dumper \@header , \@CDC;

shift @header for 1 .. 4;

unless (table_exists())
{
    my $table_structure = get_table_structure();
    print "$table_structure\n";
    run_sqlite_query($table_structure); 
    if ($?)
    {
        die "Error creating table $db_table in database $destination_dir/$db_name.db\n";
    }
}

open my $TMP_BATCH , '>', "/tmp/batch$$.sql"
    or die "can't open /tmp/batch$$.sql\n";
print $TMP_BATCH "begin transaction;\n";

my $queued =0;

for my $change (@CDC)
{
    my $op = $change->[0];
    # print "@{$change}\n";
    shift @{$change} for 1 .. 4;
    # print "@{$change}\n";
    if ($op eq 'I')
    {
        my $insert = "insert into $db_table values (";
        $insert .= join(',', map { "'$_'" } @$change);
        $insert .= ');';  
        print $TMP_BATCH "$insert \n";
        $queued++;
        # 
        # *stunt* to replicate to Apple Reminders
        #
        #if (($db_name eq 'reminders') 
        #    && (lc($db_table) eq 'shoppingsfo') 
        #    && ( -e "$ENV{HOME}/Desktop/new_reminder.workflow"))
        #{
        #    system (qq(automator -i "$change->[1]" $ENV{HOME}/Desktop/new_reminder.workflow ));
        #}
    }
    elsif($op eq 'D')
    {
        my $primary = get_table_structure('primary');
        my @primary_columns = split /,/, $primary;
        my $where_clause ='';
        for my $col ( 0 .. $#header )
        {
            for my $p (@primary_columns)
            {
                if ($p eq $header[$col])
                {
                    if ($where_clause)
                    {
                        $where_clause .= " and ";
                    }
                    $where_clause .= "$p = '$change->[$col]'";
                }
            }      
        }
        my $query = "delete from $db_table where $where_clause; ";
        print "<$query>\n"; 
        print $TMP_BATCH "$query\n"; 
        $queued++;
    }
    else
    {
        die "Unhandle operator <$op>\n";
    }
    if (($queued % 5_000) == 0)
    {
        print $TMP_BATCH "commit ;\n";
        print $TMP_BATCH "begin transaction;\n";
    }

}

print $TMP_BATCH "commit ;\n";
close $TMP_BATCH;
my $db_file = "$destination_dir/$db_name.db";
system qq($tools{sqlite} $db_file < /tmp/batch$$.sql);
unlink "/tmp/batch$$.sql";

#
#
## END 
#
#

sub run_sqlite_query
{
    my ($query) = @_;
    my $db_file = "$destination_dir/$db_name.db";
    system qq(echo "$query" | $tools{sqlite} $db_file);

}

sub table_exists 
{
    my $db_file = "$destination_dir/$db_name.db";
    return 0 unless -f $db_file;
    my $out = qx(echo '.tables' | $tools{sqlite} $db_file);
    if ($out =~ /\b$db_table\b/)
    {
        return 1;
    }
    return 0;
}

sub get_table_structure
{
    my ($only_primary) = @_;
    my %data_types = (
        enum    => 'varchar',
        set     => 'varchar',
    );
    my @columns = ();
    my $columns_query=    qq{ select column_name,data_type, character_maximum_length,column_key }
                        . qq{ from information_schema.columns }
                        . qq{ where table_schema='$db_name' and table_name='$db_table' };
    # print qq( $tools{mysql} --defaults-file=$my_cnf -BN -e "$columns_query\n");
    # system qq( $tools{mysql} --defaults-file=$my_cnf -BN -e "$columns_query");
    my $columns_def = qx( $tools{mysql} --defaults-file=$my_cnf -BN -e "$columns_query");
    if ($?)
    {
        die "Error retrieving MySQL columns\n";
    }
    # print "<$columns_def>\n";
    my @definitions = split /\n/, $columns_def;  
    my $primary='';
    my $create_table = "CREATE TABLE $db_table (";
    my $first_column =1;
    for my $col (@definitions)
    {
        my ($col_name, $col_type, $col_length, $column_key) = split ' ', $col;
        my $use_length =0;
        if ($data_types{$col_type})
        {
            $col_type=$data_types{$col_type};
        }
        if ($col_type  =~ /\b(?:char|varchar)\b/)
        {
            $use_length =1; 
        }
        if ($column_key && ($column_key eq 'PRI'))
        {
            if ($primary)
            {
                $primary .=',';
            }
            $primary .= $col_name;
        } 
        if ($first_column)
        {
            $first_column = 0;
        }
        else
        {
            $create_table .= ", ";
        }
        $create_table .= "$col_name $col_type";
        if ($use_length)
        {
            $create_table .= "($col_length)";
        }
    }
    if ($primary)
    {
        $create_table .= ", primary key ($primary)";
    }
    $create_table .= ");";
    if ($only_primary) 
    {
        return $primary;
    }
    return $create_table;
}



