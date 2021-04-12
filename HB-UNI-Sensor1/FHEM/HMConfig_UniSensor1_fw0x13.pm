package main;

use strict;
use warnings;

# device definition
$HMConfig::culHmModel{'F103'} = {name => 'HB-UNI-Sensor1', st => 'UniSensor1', cyc => '00:10', rxt => 'l:w:c:f', lst  => 'p',   chn  => ''};

# definitions for register settings
# examples see HMConfig.pm line 350ff
# 'ledMode', a=> 5.6, s=>0.2, .. is already configured in HMConfig.pm
# see also franks explanations: https://forum.fhem.de/index.php/topic,20620.msg1148330.html#msg1148330
$HMConfig::culHmRegDefine{'lowBatLimitUS1'}  = {a=>18.0,s=>1.0,l=>0,min=>1.0 ,max=>5     ,p=>'n',c=>''   ,f=>10,u=>'V' ,d=>0,t=>'Low batterie limit, step 0.1 V.'};
$HMConfig::culHmRegDefine{'updateIntervall'} = {a=>32.0,s=>2.0,l=>0,min=>60  ,max=>43200 ,p=>'n',c=>''   ,f=>'',u=>'s' ,d=>0,t=>'Sensor measure and send intervall in seconds.'};
$HMConfig::culHmRegDefine{'altitudeUS1'}     = {a=>34.0,s=>2.0,l=>0,min=>0   ,max=>10000 ,p=>'n',c=>''   ,f=>'',u=>'m' ,d=>0,t=>'Altitude for calculate air pressure at see level in meter.'};

# Register model mapping
$HMConfig::culHmRegModel{'HB-UNI-Sensor1'} = {
    'burstRx'         => 1,
    'lowBatLimitUS1'  => 1,
    'ledMode'         => 1,
    'transmDevTryMax' => 1,
    'updateIntervall' => 1,
    'altitudeUS1'     => 1
};

# subtype channel mapping
$HMConfig::culHmSubTypeSets{'UniSensor1'}    = {
    'peerChan'       => '0 <actChn> ... single [set|unset] [actor|remote|both]',
    'fwUpdate'       => '<filename> <bootTime> ...',
    'getSerial'      => '',
    'getVersion'     => '',
    'statusRequest'  => '',
    'burstXmit'      => ''
};

# Subtype spezific funtions
sub CUL_HM_ParseUniSensor1(@){
    
    my ($mFlg, $frameType, $src, $dst, $msgData, $targetDevIO) = @_;
    
    my $shash = CUL_HM_id2Hash($src);                                           #sourcehash - will be modified to channel entity
    my @events = ();

    # WEATHER_EVENT
    if ($frameType eq '70'){
        my $name = $shash->{NAME};
        my $chn = '01';

        my ($dTempBat, $pressure, $humidity, $brightness100, $digInputByte, $batVoltage, $customData) = map{hex($_)} unpack ('A4A4A2A8A2A4A4', $msgData);

        # temperature, int with scaling factor 10 from device to get one decimal place
        my $temperature =  $dTempBat & 0x7fff;
        $temperature = ($temperature &0x4000) ? $temperature - 0x8000 : $temperature;
        $temperature = sprintf('%0.1f', $temperature / 10);

        my $stateMsg = 'state:T: ' . $temperature;
        push (@events, [$shash, 1, 'temperature:' . $temperature]);

        # battery state
        push (@events, [$shash, 1, 'battery:' . ($dTempBat & 0x8000 ? 'low' : 'ok')]);

        # battery voltage in mV
        $batVoltage = sprintf('%.2f', (($batVoltage + 0.00) / 1000));
        push (@events, [$shash, 1, 'batVoltage:' . $batVoltage]);

        # air pressure, int with scaling factor 10 from device to get one decimal place
        my $pressureTxt = sprintf('%.1f', $pressure / 10);
        $stateMsg .= ' P: '    . $pressureTxt;
        push (@events, [$shash, 1, 'pressure:'    . $pressureTxt]);

        # TM: HB-UNI-Sensor1 hat eigene pressureNN Berechnung
        # falls pressureNN Berechnung in FHEM gewünscht, hier auskommentieren und ggf. anpassen
        #my ($rAltitude) = split(' ', ReadingsVal($name, 'R-altitude', 0));
        #my $altitude = AttrVal('global', 'altitude', -9999);
        #my $pressureNN = ($altitude > -9999 && $rAltitude == 0) ? sprintf('%.1f', ($pressure + ($altitude / 8.5))) : 0;
        #if ($pressureNN) {
        #   $stateMsg .= ' P-NN: ' . $pressureNN;
        #   push (@events, [$shash, 1, 'pressure-nn:' . $pressureNN]);
        #}

        # humidity
        $stateMsg .= ' H: ' . $humidity;
        push (@events, [$shash, 1, 'humidity:' . $humidity]);
        
        # brightness, int with scaling factor 100 from device to get two decimal places
        my $brightness = sprintf('%.2f', $brightness100 / 100);
        $stateMsg .= ' B: ' . $brightness;
        push (@events, [$shash, 1, 'brightness:' . $brightness]);
        
        # digital input, momentan nur 1Bit benötigt und ausgewertet
        my $digInput0 = 0;
        if ($digInputByte & 1) { $digInput0 = 1; }
        $stateMsg .= ' I: ' . $digInput0;
        push (@events, [$shash, 1, 'digitalInput:' . $digInput0]);
        
        # 16bit customData, ab Firmware 0x13
        $stateMsg .= ' X: ' . $customData;
        push (@events, [$shash, 1, 'customData:' . $customData]);
        
        # UV-Index VEML6070
        #my $uvindex =  $customData & 0x000F;
        #$stateMsg .= ' U: ' . $uvindex;
        #push (@events, [$shash, 1, 'UV-Index:' . $uvindex]);
        
        # UV-Index VEML6075
        #my $uvindex = sprintf('%.1f', ($customData & 0x00FF) / 10);
        #$stateMsg .= ' U: ' . $uvindex;
        #push (@events, [$shash, 1, 'UV-Index:' . $uvindex]);
        
        push (@events, [$shash, 1, $stateMsg]);
    }

    return @events;
}

1;
