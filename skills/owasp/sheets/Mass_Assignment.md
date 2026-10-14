# Mass Assignment Cheat Sheet

## Introduction

### Definition

Frameworks auto-bind HTTP request params into code variables/objects. Attackers can add params dev never intended → create/overwrite unintended variables/objects. Called **Mass Assignment**.

### Alternative Names

Alternative names by language/framework (CWE-915):

- **Mass Assignment:** Ruby on Rails, NodeJS.
- **Autobinding:** Spring MVC, ASP NET MVC.
- **Object injection:** PHP.

### Example

Form editing user account info:

```html
<form>
     <input name="userid" type="text">
     <input name="password" type="text">
     <input name="email" text="text">
     <input type="submit">
</form>  
```

Object form binds to:

```java
public class User {
   private String userid;
   private String password;
   private String email;
   private boolean isAdmin;

   //Getters & Setters
}
```

Controller:

```java
@RequestMapping(value = "/addUser", method = RequestMethod.POST)
public String submit(User user) {
   userService.add(user);
   return "successPage";
}
```

Typical request:

```text
POST /addUser
...
userid=bobbytables&password=hashedpass&email=bobby@tables.com
```

Exploit: sets attribute `isAdmin` of `User` instance:

```text
POST /addUser
...
userid=bobbytables&password=hashedpass&email=bobby@tables.com&isAdmin=true
```

### Exploitability

Exploitable when attacker-controlled input can init/update fields caller not authorized to change (e.g., role, account owner). Field names guessable/discoverable; source access not required. CWE-915 = insufficient control over writable attributes.

Empty constructor not general prerequisite (Spring supports constructor + setter binding). Review which inputs binding mechanism exposes, incl. nested objects.

### GitHub case study

2012: GitHub hacked via mass assignment. User uploaded public key to any organization → made changes in their repos.

### Solutions

- Prefer dedicated input objects (Data Transfer Objects, DTOs) w/ only caller-editable fields (Spring model design guidance).
- Explicitly allow-list fields when binding to object w/ extra properties.
- Never rely on block-list as sole protection: new/overlooked sensitive field stays bindable. CWE-915 recommends allowlists over denylists. Block-list examples below = mechanisms in existing apps, not recommended design.

DTOs/allowlists restrict writable properties; do not replace [authorization for the requested object and operation](Authorization.md#validate-the-permissions-on-every-request).

## General Solutions

Architectural approach: DTOs; never bind input directly to domain objects. DTO has only user-editable fields.

```java
public class UserRegistrationFormDTO {
 private String userid;
 private String password;
 private String email;

 //NOTE: isAdmin field is not present

 //Getters & Setters
}
```

## Language & Framework specific solutions

### Spring MVC

#### Allow-listing

```java
@Controller
public class UserController
{
    @InitBinder
    public void initBinder(WebDataBinder binder, WebRequest request)
    {
        binder.setAllowedFields("userid", "password", "email");
    }
...
}
```

See Spring model design guidance for dedicated input objects, allowed fields.

#### Block-listing

Spring calls `disallowedFields` fragile: fields missed/added later. Prefer allow-list above; example excludes only named property.

```java
@Controller
public class UserController
{
   @InitBinder
   public void initBinder(WebDataBinder binder, WebRequest request)
   {
      binder.setDisallowedFields("isAdmin");
   }
...
}
```

See Spring data binding limitations.

### NodeJS + Mongoose

#### Allow-listing

```javascript
var UserSchema = new mongoose.Schema({
    userid: String,
    password: String,
    email : String,
    isAdmin : Boolean,
});

UserSchema.statics = {
    User.userCreateSafeFields: ['userid', 'password', 'email']
};

var User = mongoose.model('User', UserSchema);

_ = require('underscore');
var user = new User(_.pick(req.body, User.userCreateSafeFields));
```

Docs: Underscore `pick`.

#### Block-listing

```javascript
var massAssign = require('mongoose-mass-assign');

var UserSchema = new mongoose.Schema({
    userid: String,
    password: String,
    email : String,
    isAdmin : { type: Boolean, protect: true, default: false }
});

UserSchema.plugin(massAssign);

var User = mongoose.model('User', UserSchema);

/** Static method, useful for creation **/
var user = User.massAssign(req.body);

/** Instance method, useful for updating**/
var user = new User;
user.massAssign(req.body);

/** Static massUpdate method **/
var input = { userid: 'bhelx', isAdmin: 'true' };
User.update({ '_id': someId }, { $set: User.massUpdate(input) }, console.log);
```

Docs: mongoose-mass-assign (npm).

### Ruby On Rails

Docs: Rails 3.2.9 security guide, mass assignment.

### Django

Docs: Coffee on the Keyboard, mass assignment security.

### ASP NET

Docs: OdeToCode, complete guide to mass assignment in ASP.NET MVC.

### PHP Laravel + Eloquent

#### Allow-listing

```php
<?php

namespace App;

use Illuminate\Database\Eloquent\Model;

class User extends Model
{
    private $userid;
    private $password;
    private $email;
    private $isAdmin;

    protected $fillable = array('userid','password','email');
}
```

Docs: Laravel 5.2 Eloquent mass assignment.

#### Block-listing

```php
<?php

namespace App;

use Illuminate\Database\Eloquent\Model;

class User extends Model
{
    private $userid;
    private $password;
    private $email;
    private $isAdmin;

    protected $guarded = array('isAdmin');
}
```

Docs: Laravel 5.2 Eloquent mass assignment.

### Grails

Docs: Spring blog, secure data binding with Grails.

### Play

Docs: Play 1.4.x controllers, nobinding.

### Jackson (JSON Object Mapper)

Docs: Baeldung (Jackson field serializable/deserializable); Jackson View to protect mass assignment.

### GSON (JSON Object Mapper)

Docs: Gson user guide (excluding fields); Stack Overflow answer.

### JSON-Lib (JSON Object Mapper)

Docs: JSON-Lib advanced.

### Flexjson (JSON Object Mapper)

Docs: Flexjson serialization.

## References

- Ruby on Rails: Strong Parameters
- Spring Framework: DataBinder Security Considerations
