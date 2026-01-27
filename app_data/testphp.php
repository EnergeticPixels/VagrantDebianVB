<?php
// Check if form is submitted
if ($_SERVER["REQUEST_METHOD"] === "POST") {
    // Sanitize user input to prevent XSS attacks
    $name = htmlspecialchars(trim($_POST["name"]));

    if (!empty($name)) {
        echo "<h2>Hello, $name!</h2>";
    } else {
        echo "<p style='color:red;'>Please enter your name.</p>";
    }
}
?>

<!-- HTML Form -->
<!DOCTYPE html>
<html>
<head>
    <title>Simple PHP Script</title>
</head>
<body>
    <form method="post" action="">
        <label for="name">Enter your name:</label>
        <input type="text" name="name" id="name" required>
        <button type="submit">Submit</button>
    </form>
</body>
</html>



<?php
phpinfo();
?>