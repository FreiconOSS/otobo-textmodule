package Kernel::Language::de_textmodules;

use strict;
use warnings;
use utf8;

sub Data {
    my $Self = shift;

    $Self->{Translation}->{'Text Modules'} = 'Textbausteine',
        $Self->{Translation}->{'Text module'} = 'Textbaustein',
        $Self->{Translation}->{'Text Modules Management'} = 'Verwaltung der Textbausteine',
        $Self->{Translation}->{'Text Module Category'} = 'Textbausteinkategorien',
        $Self->{Translation}->{'Text Module Category Management'} = 'Verwaltung der Textbausteincategorien',
        $Self->{Translation}->{'Add text module'} = 'Textbaustein hinzufügen',

        $Self->{Translation}->{'Filter Overview'} = 'Filter Übersicht',
        $Self->{Translation}->{'Category Selection'} = 'Auswahl Kategorie',
        $Self->{Translation}->{'Category Assignment'} = 'Zuweisung Kategorie',
        $Self->{Translation}->{'Queue Assignment'} = 'Zuweisung Queue',


        return;
}

1;
