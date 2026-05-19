rule EICAR_Test_File
{
    meta:
        description = "Detects EICAR antivirus test string for SIEM validation"
        severity = "critical"
    strings:
        $eicar = "EICAR-STANDARD-ANTIVIRUS-TEST-FILE"
    condition:
        $eicar
}
