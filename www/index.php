<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title></title>
  <link href="style.css" rel="stylesheet" />
</head>
<body>
 <h1>hello commit</h1>
 <img src="/COMMIT-Logo.png" width="1262" height="333">
 <h1> Shaul was here</h1>
 <?php
// Connecting, selecting database
$dbhost = getenv('DB_HOST');
$dbname = getenv('DB_NAME');
$dbuser = getenv('DB_USER');
$dbpassword = getenv('DB_PASSWORD');

$dbconn = pg_connect("host=$dbhost dbname=$dbname user=$dbuser password=$dbpassword")
    or die('Could not connect: ' . pg_last_error());

// Performing SQL query
$query = 'SELECT * FROM people';
$result = pg_query($dbconn, $query) or die('Query failed: ' . pg_last_error());

// Printing results in HTML
echo "<table>\n";
echo "\t<tr>\n";
echo "\t<th> ID </th>\n";
echo "\t<th> Time Created </th>\n";
echo "\t<th> Name </th>\n";
echo "\t<th> Role </th>\n";
echo "\t</tr>\n";
while ($line = pg_fetch_array($result, null, PGSQL_ASSOC)) {   
    echo "\t<tr>\n";    
    foreach ($line as $col_value) {
        echo "\t\t<td>$col_value</td>\n";
    }
    echo "\t</tr>\n";
}
echo "</table>\n";

// Free resultset
pg_free_result($result);

// Closing connection
pg_close($dbconn);

?>
</body>
</html>