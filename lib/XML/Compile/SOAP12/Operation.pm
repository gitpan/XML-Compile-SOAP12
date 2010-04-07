# Copyrights 2009-2010 by Mark Overmeer.
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 1.06.
use warnings;
use strict;

##### WARNING: this is just a blunt copy of SOAP11::Operation, so it
##### does ****NOT IMPLEMENT**** soap12 yet. Used for $wsdl->printIndex
##### when it contains soap12 info.

package XML::Compile::SOAP12::Operation;
use vars '$VERSION';
$VERSION = '2.01';

use base 'XML::Compile::Operation';

use Log::Report    'xml-compile-soap12', syntax => 'SHORT';
use List::Util     'first';
use File::Basename 'dirname';

use XML::Compile::Util         qw/pack_type unpack_type/;
use XML::Compile::SOAP::Util   qw/:wsdl11/;
use XML::Compile::SOAP12::Util qw/:soap12/;
use XML::Compile::SOAP12::Client;
use XML::Compile::SOAP12::Server;

our $VERSION;         # OODoc adds $VERSION to the script
$VERSION ||= 'undef';

__PACKAGE__->register(WSDL11SOAP12, SOAP12ENV);

# client/server object per schema class, because initiation options
# can be different.  Class reference is key.
my (%soap12_client, %soap12_server);


sub init($)
{   my ($self, $args) = @_;

    $self->SUPER::init($args);

    $self->{$_}    = $args->{$_} || {}
        for qw/input_def output_def fault_def/;

    $self->{style} = $args->{style} || 'document';
    $self;
}

sub _initWSDL11($)
{   my ($class, $wsdl) = @_;

    trace "initialize SOAP12 operations for WSDL11";

    $wsdl->prefixes(soap12 => WSDL11SOAP12);
    $wsdl->addKeyRewrite('PREFIXED(soap12)');

    my $dir = dirname __FILE__;
    my @xsd = (glob("$dir/xsd/*"), glob("$dir/../WSDL11/xsd/wsdl-soap12.xsd"));
    $wsdl->importDefinitions(\@xsd);

    $wsdl->declare(READER =>
      [ "soap12:address", "soap12:operation", "soap12:binding"
      , "soap12:body",    "soap12:header",    "soap12:fault" ]);
}

sub _fromWSDL11(@)
{   my ($class, %args) = @_;

    # Extract the SOAP12 specific information from a WSDL11 file.  There are
    # half a zillion parameters.
    my ($p_op, $b_op, $wsdl)
      = @args{ qw/port_op bind_op wsdl/ };

    $args{schemas}   = $wsdl;
    $args{endpoints} = $args{serv_port}{soap_address}{location};

    my $sop = $b_op->{soap_operation}     || {};
    $args{action}  ||= $sop->{soapAction} || '';

    my $sb = $args{binding}{soap_binding} || {};
    $args{transport} = $sb->{transport}   || 'HTTP';
    $args{style}     = $sb->{style}       || 'document';

    $args{input_def} = $class->_msg_parts($wsdl, $args{name}, $args{style}
      , $p_op->{wsdl_input}, $b_op->{wsdl_input});

    $args{output_def} = $class->_msg_parts($wsdl, $args{name}.'Response'
      , $args{style}, $p_op->{wsdl_output}, $b_op->{wsdl_output});

    $args{fault_def}
      = $class->_fault_parts($wsdl, $p_op->{wsdl_fault}, $b_op->{wsdl_fault});

    $class->SUPER::new(%args);
}

sub _msg_parts($$$$$)
{   my ($class, $wsdl, $opname, $style, $port_op, $bind_op) = @_;
    my %parts;

    defined $port_op          # communication not in two directions
        or return ({}, {});

    if(my $body = $bind_op->{soap_body})
    {   my $msgname   = $port_op->{message};
        my @parts     = $class->_select_parts($wsdl, $msgname, $body->{parts});

        my ($ns, $local) = unpack_type $msgname;
        my $procedure;
        if($style eq 'rpc')
        {   exists $body->{namespace}
                or error __x"rpc operation {name} requires namespace attribute"
                     , name => $msgname;
            my $ns = $body->{namespace};
            $procedure = pack_type $ns, $opname;
        }
        else
        {   $procedure = @parts==1 && $parts[0]{type} ? $msgname : $local; 
        }

        $parts{body}  = {procedure => $procedure, %$port_op, use => 'literal',
           %$body, parts => \@parts};
    }

    my $bsh = $bind_op->{soap_header} || [];
    foreach my $header (ref $bsh eq 'ARRAY' ? @$bsh : $bsh)
    {   my $msgname  = $header->{message};
        my @parts    = $class->_select_parts($wsdl, $msgname, $header->{part});
         push @{$parts{header}}, { %$header, parts => \@parts };

        foreach my $fault ( @{$header->{headerfault} || []} )
        {   $msgname = $fault->{message};
            my @hf   = $class->_select_parts($wsdl, $msgname, $fault->{part});
            push @{$parts{headerfault}}, { %$fault,  parts => \@hf };
        }
    }
    \%parts;
}

sub _select_parts($$$)
{   my ($class, $wsdl, $msgname, $need_parts) = @_;
    my $msg = $wsdl->findDef(message => $msgname)
        or error __x"cannot find message {name}", name => $msgname;

    my @need
      = ref $need_parts     ? @$need_parts
      : defined $need_parts ? $need_parts
      : ();

    my $parts = $msg->{wsdl_part} || [];
    @need or return @$parts;

    my @sel;
    my %parts = map { ($_->{name} => $_) } @$parts;
    foreach my $name (@need)
    {   my $part = $parts{$name}
            or error __x"message {msg} does not have a part named {part}"
                  , msg => $msg->{name}, part => $name;

        push @sel, $part;
    }

    @sel;
}

sub _fault_parts($$$)
{   my ($class, $wsdl, $portop, $bind) = @_;

    my $port_faults  = $portop || [];
    my %faults;

    my @sel;
    foreach my $fault (map {$_->{soap_fault}} @$bind)
    {   my $name  = $fault->{name};

        my $port  = first {$_->{name} eq $name} @$port_faults;
        defined $port
            or error __x"cannot find port for fault {name}", name => $name;

        my $msgname = $port->{message}
            or error __x"no fault message name in portOperation";

        my $message = $wsdl->findDef(message => $msgname)
            or error __x"cannot find fault message {name}", name => $msgname;

        @{$message->{wsdl_part} || []}==1
            or error __x"fault message {name} must have one part exactly"
                  , name => $msgname;

        $faults{$name} =
          { part => $message->{wsdl_part}[0]
          , use  => ($fault->{use} || 'literal')
          };
    }

    {faults => \%faults };
}

#-------------------------------------------


sub style()     {shift->{style}}
sub version()   { 'SOAP12' }
sub serverClass { 'XML::Compile::SOAP12::Server' }
sub clientClass { 'XML::Compile::SOAP12::Client' }

#-------------------------------------------


sub compileHandler(@)
{   my ($self, %args) = @_;

    my $soap = $soap12_server{$self->{schemas}}
      ||= XML::Compile::SOAP12::Server->new(schemas => $self->{schemas});
    my $style = $args{style} ||= $self->style;
    my $kind  = $args{kind} ||= $self->kind;

    my @ro    = (%{$self->{input_def}},  %{$self->{fault_def}});
    my @so    = (%{$self->{output_def}}, %{$self->{fault_def}});
    my $sel   = $args{selector}
             || $soap->compileFilter(%{$self->{input_def}});

    $soap->compileHandler
      ( name      => $self->name
      , kind      => $kind
      , selector  => $sel
      , encode    => $soap->_sender(@so, %args)
      , decode    => $soap->_receiver(@ro, %args)
      , callback  => $args{callback}
      );
}


sub compileClient(@)
{   my ($self, %args) = @_;

    my $soap = $soap12_client{$self->{schemas}}
      ||= XML::Compile::SOAP12::Client->new(schemas => $self->{schemas});
    my $style = $args{style} ||= $self->style;
    my $kind  = $args{kind}  ||= $self->kind;

    my @so   = (%{$self->{input_def}},  %{$self->{fault_def}});
    my @ro   = (%{$self->{output_def}}, %{$self->{fault_def}});

    $soap->compileClient
      ( name         => $self->name
      , kind         => $kind
      , encode       => $soap->_sender(@so, %args)
      , decode       => $soap->_receiver(@ro, %args)
      , transport    => $self->compileTransporter(%args)
      );
}


sub explain($$$@)
{   my ($self, $schema, $format, $dir, %args) = @_;

    # $schema has to be passed as argument, because we do not want operation
    # objects to be glued to a schema object after compile time.

    $format eq 'PERL'
       or error __x"only PERL template supported for the moment, not {got}"
            , got => $format;

    my $style       = $self->style;
    my $opname      = $self->name;
    my $skip_header = delete $args{skip_header} || 0;
    my $recurse     = delete $args{recurse}     || 0;

    my $def = $dir eq 'INPUT' ? $self->{input_def} : $self->{output_def};

    my (@struct, @attach);
    my @main = $recurse
       ? "# The details of the types and elements are attached below."
       : "# To explore the HASHes for each part, use recurse option.";

    foreach my $part ( @{$def->{body}{parts} || []} )
    {   my $name = $part->{name};
        my ($kind, $value) = $part->{type} ? (type => $part->{type})
          : (element => $part->{element});

        push @main, ''
          , "# Part $kind $value"
          , ($kind eq 'type' && $recurse ? "# See fake element '$name'" : ())
          , "my \$$name = {};";
        push @struct, "    $name => \$$name,";

        $recurse or next;

        my $elem = $value;
        if($kind eq 'type')
        {   # generate element with part name, because template requires elem
            $schema->compileType(READER => $value, element => $name);
            $elem = $name;
        }

        push @attach, ''
          , $schema->template(PERL => $elem, skip_header => 1, %args);
    }

    if($dir eq 'INPUT')
    {   push @main, ''
         , '# Call with the combination of parts.'
         , 'my @params = (', @struct, ');'
         , 'my ($answer, $trace) = $call->(@params);', ''
         , '# @params will become %$data_in in the server handler.'
         , '# $answer is a HASH, an operation OUTPUT or Fault.'
         , '# $trace is an XML::Compile::SOAP::Trace object.'
    }
    elsif($dir eq 'OUTPUT')
    {   s/^/   / for @main, @struct;
        unshift @main, ''
         , "sub handle_$opname(\$)"
         , '{  my ($server, $data_in) = @_;'
         , '   # process $data_in, structured as INPUT message.'
         , '   # Hint: use "print Dumper $data_in"';

        push @main, ''
         , '   # This will end-up as $answer at client-side'
         , "   return    # optional keyword"
         , "   +{", @struct, "    };", "}";
    }
    else
    {   error __x"template for direction INPUT or OUTPUT, not {got}"
          , got => $dir;
    }

    my @header;
    push @header
      , "# Operation $def->{body}{procedure}"
      , "#           $dir $style $def->{body}{use}"
      , "# Produced  by ".__PACKAGE__." version $VERSION"
      , "#           on ".localtime()
      , "#"
      , "# The output below is only an example: it cannot be used"
      , "# without interpretation, although very close to real code."
      , ""
        unless $args{skip_header};

    if($dir eq 'INPUT')
    {   push @header
          , '# Compile only once in your code, usually during initiation:'
          , "my \$call = \$wsdl->compileClient('$opname');"
          , '# ... then call it as often as you need.';
    }
    else #OUTPUT
    {   push @header
          , '# As part of the initiation phase of your server:'
          , 'my $daemon = XML::Compile::SOAP::HTTPDaemon->new;'
          , '$deamon->operationsFromWSDL($wsdl,'
          , "   callbacks => {$opname => \\&handle_$opname} );"
    }

    join "\n", @header, @main, @attach, '';
}

1;
