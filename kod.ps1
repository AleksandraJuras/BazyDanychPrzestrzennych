
$TIMESTAMP = (Get-Date -format MM/dd/yyyy)

function BDate
{
    param()

    $data = Get-Date
    $data = "{0:yyyy-MM-dd HH:mm:ss}" -f ($data) 
    $data
}
function putToLog
{
    param($komunikat)

    $pobierzDate = BDate
    $pobierzDate + "  OPERACJA - $komunikat - PRZEBIEGŁA POMYSLNIE" >> "D:\Documents\Aleksandra_Juras\Studia_sem_5\Bazy_danych_przestrzennych\powershell\cwiczenie6_${TIMESTAMP}.log"
}

# a. pobierz plik

try
{
$URL = "https://home.agh.edu.pl/~wsarlej/Customers_Nov2021.zip"
$dest = "D:\Documents\Aleksandra_Juras\Studia_sem_5\Bazy_danych_przestrzennych\powershell\ZipFile.zip"
Invoke-WebRequest -Uri $URL -OutFile $dest
putToLog("Pobranie pliku")
}
catch 
{
    An error occurred that could not be resolved."
}


# b. rozpakuje go używając hasła

try
    {
    $password = "agh"
    $unzip = "D:\Documents\Aleksandra_Juras\Studia_sem_5\Bazy_danych_przestrzennych\powershell"
    # Install-Module -Name 7Zip4Powershell
    Expand-7Zip -ArchiveFileName $dest -TargetPath $unzip -Password $password 
    putToLog("Rozpakowanie pliku")
    }
catch 
    {
       "An error occurred that could not be resolved."
    }



# c. odrzuci błędne wiersze do pliku Customers_Nov2021.bad_${TIMESTAMP}

try{
$costumer_old = "D:\Documents\Aleksandra_Juras\Studia_sem_5\Bazy_danych_przestrzennych\powershell\Customers_old.csv"
$plik1 = Get-Content -Path (Join-Path -Path $unzip -ChildPath "\Customers_Nov2021.csv") | Where-Object { $_.Trim() -ne '' } 

# porównam po emailach bo musza byc one uniaklne

# $plik1 = Get-Content -Path "D:\Documents\Aleksandra_Juras\Studia_sem_5\Bazy_danych_przestrzennych\powershell\Customers_Nov2021_clean.csv"
$plik2 = Get-Content -Path "D:\Documents\Aleksandra_Juras\Studia_sem_5\Bazy_danych_przestrzennych\powershell\Customers_old.csv"

$compare = Compare-Object -referenceObject $plik1 -differenceObject $plik2

    for($i = 1; $i -lt $plik1.Count; $i++)
    {
        for($j = 0; $j -lt $plik2.Count; $j++)
        {
            if($plik1[$i] -eq $plik2[$j])
            {
                $plik1[$i] >> "D:\Documents\Aleksandra_Juras\Studia_sem_5\Bazy_danych_przestrzennych\powershell\Customers_Nov2021.bad_${TIMESTAMP}"
                $plik1[$i] = $null
            }
        }
    } 

    $plik1 > "D:\Documents\Aleksandra_Juras\Studia_sem_5\Bazy_danych_przestrzennych\powershell\Customers_Nov2021_new.csv" 
    putToLog("CZyszczenie pliku")
}
catch
{
    "An error occurred that could not be resolved."
}


# d. PostgreSQL utworzy tabelę

try
{
Set-Location 'C:\Program Files\PostgreSQL\13\bin\'

$env:USER = "postgres"
$env:PGPASSWORD = 'latbla36ve'
$env:NEWDATABASE = "zaj8"
$env:TABLE = "COSTUMERS_400581" # tu było wczesniej cw8
$env:SERVER  ="PostgreSQL 13"
$env:PORT = "5432"

psql -U postgres -d $env:NEWDATABASE -w -c "CREATE TABLE IF NOT EXISTS $env:TABLE (first_name VARCHAR(20), last_name VARCHAR(30) PRIMARY KEY, email VARCHAR(40), lat FLOAT(50), long FLOAT(50))"
putToLog("Tworzenie tabeli w PgAdmin")
}
catch
{
    "An error occurred that could not be resolved."
}


# e. załaduje dane ze zweryfikowanego pliku do tabeli

# tutaj otworzyłam plik w notepadzie ++ i zmieniłam kodowanie na utf8
try
{
psql -d $env:NEWDATABASE -U postgres -c "\copy $env:TABLE from D:\Documents\Aleksandra_Juras\Studia_sem_5\Bazy_danych_przestrzennych\powershell\PROCESSED_12.15.2021\Customers_Nov2021_new.csv delimiter ',' csv header;"
putToLog("załadowanie danych do tabeli")
}
catch 
{
    "An error occurred that could not be resolved."
}


# f. przeniesie przetworzony plik do podkatalogu

try{
    $destfile = New-Item -type directory -path  "D:\Documents\Aleksandra_Juras\Studia_sem_5\Bazy_danych_przestrzennych\powershell\PROCESSED_${TIMESTAMP}" 
    Move-Item -Path "D:\Documents\Aleksandra_Juras\Studia_sem_5\Bazy_danych_przestrzennych\powershell\Customers_Nov2021_new.csv" -Destination $destfile
    putToLog("przeniesienie pliku do podkatalogu")
    }
catch
{
    "An error occurred that could not be resolved."
}

# g. wyśle email zawierający nst. rapor


try
{
# policzy ilosci wierszy
$lengthForLoaded = (Get-Content D:\Documents\Aleksandra_Juras\Studia_sem_5\Bazy_danych_przestrzennych\powershell\Customers_Nov2021.csv).Length
$lengthForBad = (Get-Content D:\Documents\Aleksandra_Juras\Studia_sem_5\Bazy_danych_przestrzennych\powershell\Customers_Nov2021.bad_12.14.2021).Length
$lengthForGood = (Get-Content D:\Documents\Aleksandra_Juras\Studia_sem_5\Bazy_danych_przestrzennych\powershell\PROCESSED_12.15.2021\Customers_Nov2021_new.csv).Length

Set-Location 'C:\Program Files\PostgreSQL\13\bin\'
$lenghtForTable = psql -d $env:NEWDATABASE -U postgres -c "SELECT COUNT(*) FROM $env:TABLE"


    $MyEmail = "aleksandra37.juras@gmail.com"
    $SMTP= "smtp.gmail.com"
    $Subject = "CUSTOMERS LOAD - ${TIMESTAMP}"
    $Body = "liczba wierszy w pliku pobranym z internetu: $lengthForLoaded`n
    liczba poprawnych wierszy (po czyszczeniu): $lengthForGood`n
    liczba duplikatow w pliku wejsciowym: $lengthForBad`n 
    ilosc danych zaladowanych do tabeli: $lenghtForTable"
    $Creds = (Get-Credential -Credential "$MyEmail")


Send-MailMessage -To $MyEmail -From $MyEmail -Subject $Subject -Body $Body -SmtpServer $SMTP -Credential $Creds -UseSsl -Port 587 -DeliveryNotificationOption never
putToLog("wysłanie emaila z liczbą wierszy")
}
catch
{
    "An error occurred that could not be resolved."
}


# h. uruchomi kwerendę SQL, która znajdzie imiona i nazwiska klientów, którzy mieszkają w promieniu 50 kilometrów od punktu: 41.39988501005976, -75.67329768604034 (funkcja ST_DistanceSpheroid) i zapisze je do tabeli BEST_CUSTOMERS_${NUMERINDEKSU}

try
{
    New-Item -Path "D:\Documents\Aleksandra_Juras\Studia_sem_5\Bazy_danych_przestrzennych\powershell\zapytanie.txt" -ItemType File
    Set-Content -Path "D:\Documents\Aleksandra_Juras\Studia_sem_5\Bazy_danych_przestrzennych\powershell\zapytanie.txt"  -Value "SELECT first_name, last_name  INTO best_customers_400581 FROM costumers_400581
				    WHERE ST_DistanceSpheroid( ST_Point(lat, long), ST_Point(41.39988501005976, -75.67329768604034), 'SPHEROID[""WGS 84"",6378137,298.257223563]') <= 50000"

    psql -d $env:NEWDATABASE -U postgres -f "D:\Documents\Aleksandra_Juras\Studia_sem_5\Bazy_danych_przestrzennych\powershell\zapytanie.txt"
    putToLog("zapytanie sql")
}
catch
{
    "An error occurred that could not be resolved."
}


# i. wyeksportuje zawartość tabeli BEST_CUSTOMERS_${NUMERINDEKSU} do pliku csv o takiej samej nazwie jak tabela źródłowa,

try
{
$env:TABLEbest = "best_customers_400581"

    $zapisz = psql -U postgres -d $env:NEWDATABASE -c "SELECT * FROM $env:TABLEbest" 
    $table = @()

    for ($i=2; $i -lt $zapisz.Count-2; $i++)
    {
        $content = New-Object -TypeName PSObject
        $content | Add-Member -Name 'first_name' -MemberType Noteproperty -Value $zapisz[$i].Split( "|")[0].replace(" ", "")
        $content | Add-Member -Name 'last_name' -MemberType Noteproperty -Value $zapisz[$i].Split( "|")[1].replace(" ", "")
        $table += $content
    }

    $table | Export-Csv -Path "D:\Documents\Aleksandra_Juras\Studia_sem_5\Bazy_danych_przestrzennych\powershell\new.csv" -NoTypeInformation
    putToLog("eksport do tabeli csv")
}
catch
{
    "An error occurred that could not be resolved."
}






