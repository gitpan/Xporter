#!/usr/bin/perl
use warnings; use strict;
# vim=:SetNumberAndWidth

{ package Xporter;
	use warnings; use strict;
	our $VERSION='0.0.10';
	# 0.0.10 - Remove P from another test (missed one);  Having to use
	#         replacement lang features is torture  on my RSI
	# 0.0.9 - add alternate version format for ExtMM(this system sucks)
	#       - remove diagnostic messages from tests (required P)
	# 0.0.8 - add current dep for BUILD_REQ of ExtMM
	# 0.0.7 - 'require' version# bugfix
	# 0.0.6 - comment cleanup; Change CONFIGURE_REQUIRES to TEST_REQUIRES
	# 0.0.5 - export inheritance test written to highlight a problem area
	# 			- problem area addessed; converted to use efficient jump table
	#	0.0.4 - documentation additions;
	#				- added tests & corrected any found problems
	#	0.0.3 - added auto-ISA-adding (via push) when this mod is used.
	#	      - added check for importing 'import' to disable auto-ISA-add
	# 0.0.2	- Allow for "!" as first arg to import to turn off default export
	# 				NOTE: defaults are defaults when using EXPORT_OK as well;
	# 							One must specifically disable defaults to turn them off.
	# 0.0.1	- Initial split of code from iomon
	#
	#require 5.8.0;
	
	# Alternate export-import method that doesn't undefine defaults by 
	# default

	sub add_to_caller_ISA($$) {
		my ($pkg, $caller) = @_;
			
		if ($pkg eq __PACKAGE__) { no strict 'refs';
			unshift @{$caller."::ISA"}, $pkg unless grep /$pkg/, @{$caller."::ISA"};
		}
	}

	sub cmp_ver($$) {
		my ($v1, $v2) = @_;
		my $i=0;
		while($i<@$v2 && $i<@$v1) {
			my $r = $v1->[$i] cmp $v2->[$i];
			return 1 if $r>=0;
			++$i;
		}
		return 0;
	}

	our %exporters;

	sub import { 
		my $pkg			= shift;
		my ($caller, $fl, $ln)	= (caller);

		if (@_ && $_[0] =~ /^v?([\d\._]+)$/) {
			my $verwanted = $1;
			my @v1=split /_|\./, $verwanted;
			my @v2=split /_|\./, $VERSION;
				if (cmp_ver(\@v1, \@v2) < 0 ) {
				require Carp; 
				Carp::croak(sprintf "File %s at line %s wanted version".
				" %s of %s. ".
				"	We have version %s.\n", $fl, $ln, $verwanted, $pkg, $VERSION);
			}
			shift;
		}

		if ($pkg eq __PACKAGE__) {		# we are exporting

			if (@_ && $_[0] eq q(import)) {
				no strict q(refs);
				*{$caller."::import"} = \*{$pkg."::import"};
			} else {
				add_to_caller_ISA($pkg, $caller);
			}
			$exporters{$caller} = 1;
			return 1;
		}

		my ($export, $exportok, $exporttags);

		{ no strict q(refs);
			$export = \@{$pkg."::"."EXPORT"} || [];
			$exportok = \@{$pkg."::"."EXPORT_OK"} || [];
			$exporttags = \%{$pkg."::"."EXPORT_TAGS"};
		}

		
		my @allowed_exports = (@$export, @$exportok);

		if (@_ and $_[0] eq '!' 	|| $_[0] eq '-' ) {
			$export=[];
			shift @_;
		}

		for (@_) {
			push @$export, $_ if grep { /$_/ } @allowed_exports;
		}

		my $tc2proto = {'&' => '&', '$'  => '$', '@' => '@',
										'%'	=> '%', '*' => '*', };

		for(@$export) {
			my $type = substr $_, 0, 1;
			if (exists $tc2proto->{$type}) { $_ = substr($_,1) } 
			elsif ($type =~ /\w/) { $type='&' }
			else { require Carp; Carp::croak("Unknown type $type in $_"); }
			my $colon_name	= "::" . $_ ;
			my ($exf, $imf)	= ( $pkg . $colon_name, $caller . $colon_name);
			no strict q(refs);
			my $case = {
				'&'	=>	\&$exf,
				'$'	=>	\$$exf,
				'@' =>	\@$exf,
				'%' =>	\%$exf,
				'*'	=>	 *$exf};
			*$imf = $case->{$type};
		}
	}
1}

=encoding utf-8

=head1 NAME


Xporter - Alternative Exporter with persistant defaults & auto-ISA


=head1 VERSION

Version "0.0.10"


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


