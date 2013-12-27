#!/usr/bin/perl
use warnings; use strict;
# vim=:SetNumberAndWidth

{ package Xporter;
	use warnings; use strict;
	our $VERSION='0.0.4';
	#	0.0.4 - documentation additions;
	#				- added tests & corrected any found problems
	#	0.0.3 - added auto-ISA-adding (via push) when this mod is used.
	#	      - added check for importing 'import' to disable auto-ISA-add
	# 0.0.2	- Allow for "!" as first arg to import to turn off default export
	# 				NOTE: defaults are defaults when using EXPORT_OK as well;
	# 							One must specifically disable defaults to turn them off.
	# 0.0.1	- Initial split of code from iomon
	#
	require 5.8.0;

	# Alternate export-import method that doesn't undefine defaults by 
	# default

	my $tc2proto = {'&' => '&', '$'  => '$', '@' => '@',
										'%'	=> '%', '*' => '*', 
									};

	sub add_to_caller_ISA($$) {
		my ($pkg, $caller) = @_;
			
		if ($pkg eq __PACKAGE__) { 
			no strict 'refs';
			push @{$caller."::ISA"}, __PACKAGE__
				unless grep /__PACKAGE__/, @{$caller."::ISA"};
		}
	}

	our %exporters;

	sub import { my $pkg = shift;
		my $caller	= (caller)[0];

		if ($pkg eq __PACKAGE__) {		# we are exporting

			if (@_ && $_[0] eq q(import)) {
				no strict q(refs);
				*{$caller."::import"} = \*{__PACKAGE__."::import"};
			} else {
				add_to_caller_ISA($pkg, $caller);
			}
			$exporters{$caller} = 1;
			return 1;
		}

		my ($simple , $export, $exportok, $exporttags);
		my @non_simple;

		$simple = [ grep { /^\w/ or ((push @non_simple,$_), undef) } @_ ];

		{ no strict q(refs);
			$export = \@{$pkg."::"."EXPORT"} || [];
			$exportok = \@{$pkg."::"."EXPORT_OK"} || [];
			$exporttags = \%{$pkg."::"."EXPORT_TAGS"};
		}
		
		my @allowed_exports = (@$export, @$exportok);

		if (@_ and $_[0] eq '!' 	|| $_[0] eq '-' ) {
			$#$export=-1;
			shift @_;
		}

		for my $Xok (@_) {
			push @$export, $Xok if grep /\Q$Xok\E/, @allowed_exports;
		}
		for(@$export) {
			my $type = substr $_, 0, 1;
			if (exists $tc2proto->{$type}) { $_ = substr($_,1) } 
			else { $type='&' }
			my $pt = $tc2proto->{$type};
			my $colon_name	= "::" . $_ ;
			my ($exf, $imf)	= ( $pkg . $colon_name, $caller . $colon_name);
			if ($type eq '&') { no strict 'refs';
				*$imf = \&$exf;
			} else {
				$pt = "\\$pt";
				my $prg = "*$imf = $pt$exf";
				eval '# line ' . __LINE__ .' '. __FILE__ ."\n
							$prg";
				$@ and warn $@;
			}
		}
	}
1}

=encoding utf-8

=head1 NAME


Xporter - an exporter with persistant defaults & auto-ISA


=head1 VERSION

Version "0.0.4"


=head1 SYNOPIS

In the "Exporting" module:

  { package module_adder; use warnings; use strict;
    use mem;
    our (@EXPORT, @EXPORT_OK);
    our $lastsum;
    our @lastargs;
    use Xporter(@EXPORT=qw(adder $lastsum @lastargs), 
            		@EXPORT_OK=qw(print_last_result));

    sub adder($$) {@lastargs=@_; $lastsum=$_[0]+$_[1]}
    sub print_last_result () {
      use P;    # using P allows answer printed or as string
      if (@lastargs && defined $lastsum){
        P "%s = %s\n", (join ' + ' , @lastargs), $lastsum;
      }
    }
  }

In using module (same or different file)

  package main;  use warnings; use strict;
  use module_adder qw(print_last_result);

  adder 4,5;

Printing output:

  print_last_result();

  #Result:
  
  4 + 5 = 9

(Or in a test:)
	
  ok(print_last_result eq "4 + 5 = 9", "a pod test");

=head1 DESCRIPTION

C<Xporter> provides Export functionality similar to Exporter, with
some different behaviors to simplify common cases.

One primary difference, in C<Xporter> is that the default EXPORT list
remains the default EXPORT list unless you specifically ask for it
to not be included.

In Exporter, if you ask for an addition export from the EXPORT_OK
list, you automatically lose your I<defaults>.  The theory here being
that if you want something extra you shouldn't be required to lose
your default list.  The default list is easily enough NOT included
by specifying '-' or '!' as the first parameter in the client's 
import list. 

=head2 Example

Suppose your exporting function has exports:

  our (@EXPORT, @EXPORT_OK);
  use Xporter(@EXPORT=qw(one $two %three @four), 
              @EXPORT_OK=qw(&five));

In the using module, to only import symbols 'two' and 'five', 
one would use:

  use MODULENAME qw(! $two five);

That negates the default EXPORT list, and lets you selectively
import the values you want from either the default or the OK list
(modules in the default list don't need to be relisted in the OK list
as it is presumed that they were OK to be exported or they would not
have been defaults).

Other functions of Exporter are not currently implemented though
may appear in later versions should those features be needed.

Listing the EXPORT and EXPORT_OK assignments as params to Xporter 
allow their types to be available to importing modules at compile time.


