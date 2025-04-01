function GetName{
    Write-Host "Manoj" -ForegroundColor Green
}


class Person {
    [string]$Name
    [int]$Age

    # 构造函数
    Person([string]$name, [int]$age) {
        $this.Name = $name
        $this.Age  = $age
    }

    # 方法
    [string] GetInfo() {
        GetName
        return "Name: $($this.Name), Age: $($this.Age)"
    }

    [Void] GetMessage(){

    }
}

# 创建对象
$person1 = [Person]::new("Bob", 30)

# 访问属性
$person1.Name  # 输出: Bob
$person1.Age   # 输出: 30

# 调用方法
$person1.GetInfo()  # 输出: Name: Bob, Age: 30


class Employee : Person {
    [string]$JobTitle

    Employee([string]$name, [int]$age, [string]$jobTitle) : base($name, $age) {
        $this.JobTitle = $jobTitle
    }

    [string] GetInfo() {
        return "Name: $($this.Name), Age: $($this.Age), Job: $($this.JobTitle)"
    }
}

# 创建对象
$emp1 = [Employee]::new("Charlie", 28, "Software Engineer")

# 调用方法
$emp1.GetInfo()  # 输出: Name: Charlie, Age: 28, Job: Software Engineer


class MathUtils {
    static [int] Square([int]$num) {
        return $num * $num
    }
}

# 调用静态方法
[MathUtils]::Square(5)  # 输出: 25

$Script:usernmae = "李四"

function GetName{
    $Script:usernmae = "Manoj"
}
GetName
Write-Host "你好，"$usernmae -ForegroundColor Green