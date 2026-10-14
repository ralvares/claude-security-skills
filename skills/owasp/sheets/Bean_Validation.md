# Bean Validation Cheat Sheet

## Introduction

Actionable guidance for Java Bean Validation security functionality.

Bean validation (aka Jakarta Validation) = common way to do [input validation](Input_Validation.md) in Java. App-layer-agnostic spec: define validation constraints on domain model once, validate across app tiers. Constraints + validators written once → less duplication, uniform behavior.

### Typical Validation

![Typical](../assets/Bean_Validation_Cheat_Sheet_Typical.png)

### Bean Validation

![JSR](../assets/Bean_Validation_Cheat_Sheet_JSR.png)

## Setup

Examples use legacy `javax.validation` API (built-in constraint package) w/ Hibernate Validator. Jakarta Validation 3.0 uses `jakarta.validation`; use API and provider versions compatible w/ app.

Add Hibernate Validator to **pom.xml**:

```xml
<dependency>
   <groupId>org.hibernate</groupId>
   <artifactId>hibernate-validator</artifactId>
   <version>USE_LATEST_VERSION</version>
</dependency>
```

Enable bean validation in Spring **context.xml**:

```xml
<beans:beans ...
   ...
   <mvc:annotation-driven />
   ...
</beans:beans>
```

See Hibernate Validator setup guide.

## Basics

Add validation constraints (`@Pattern`, `@Digits`, `@Min`, `@Max`, `@Size`, `@Past`, `@Future`, `@CreditCardNumber`, `@Email`, `@URL`, etc.) to model, use `@Valid` when passing model between app layers.

Constraints apply to:

- Fields
- Properties
- Classes

Bean Validation 1.1 also:

- Parameters
- Return values
- Constructors

Examples use field constraints, validation triggered by controller. See Bean Validation docs for full list.

Hibernate Validator returns `BindingResult` containing `List<ObjectError>`. Examples use simplistic error handling; production app needs fuller design: logging, error page redirection.

## Predefined Constraints

### @Pattern

**Annotation**:

`@Pattern(regexp=,flags=)`

**Data Type**:

`CharSequence`

**Use**:

Checks annotated string matches regex given flag match. See OWASP Validation Regex Repository for useful regexes.

**Reference**:

Documentation

**Model**:

```java
import javax.validation.constraints.Pattern;

public class Article  {
 //Constraint: One or more ASCII letters, digits, or spaces
 @Pattern(regexp = "[a-zA-Z0-9 ]+")
 private String articleTitle;
 public String getArticleTitle()  {
  return  articleTitle;
 }
 public void setArticleTitle(String  articleTitle)  {
   this.articleTitle  =  articleTitle;
  }

  ...

}
```

**Controller**:

```java
import javax.validation.Valid;
import com.company.app.model.Article;

@Controller
public class ArticleController  {

 ...

 @RequestMapping(value = "/postArticle",  method = RequestMethod.POST)
 public @ResponseBody String postArticle(@Valid  Article  article,  BindingResult  result,
 HttpServletResponse  response) {
  if (result.hasErrors()) {
   String errorMessage  =  "";
   response.setStatus(HttpServletResponse.SC_BAD_REQUEST);
   List<ObjectError> errors = result.getAllErrors();
   for(ObjectError  e :  errors) {
    errorMessage += "ERROR: " +  e.getDefaultMessage();
   }
   return  errorMessage;
  } else {
   return  "Validation Successful";
  }
 }
}
```

### @Digits

**Annotation**:

`@Digits(integer=,fraction=)`

**Data Type**:

`BigDecimal`, `BigInteger`, `CharSequence`, `byte`, `short`, `int`, `long` + wrappers of primitive types; HV also: any sub-type of Number

**Use**:

Checks value is number w/ up to integer digits and fraction fractional digits

**Reference**:

Documentation

**Model**:

```java
import javax.validation.constraints.Digits;

public class Customer {
  //Constraint: Age can only be 3 digits long or less
  @Digits(integer = 3, fraction = 0)
  private int age;

  public int getAge()  {
    return age;
  }

  public void setAge(int age)  {
      this.age = age;
    }

    ...
}
```

**Controller**:

```java
import javax.validation.Valid;
import com.company.app.model.Customer;

@Controller
public class CustomerController  {

 ...

 @RequestMapping(value = "/registerCustomer",  method = RequestMethod.POST)
 public @ResponseBody String registerCustomer(@Valid Customer customer, BindingResult result,
 HttpServletResponse  response) {

  if (result.hasErrors()) {
   String errorMessage = "";
   response.setStatus(HttpServletResponse.SC_BAD_REQUEST);
   List<ObjectError> errors = result.getAllErrors();

   for( ObjectError  e :  errors) {
    errorMessage += "ERROR: "  +  e.getDefaultMessage();
   }
   return  errorMessage;
  } else {
   return  "Validation Successful";
  }
 }
}
```

### @Size

**Annotation**:

`@Size(min=,` `max=)`

**Data Type**:

`CharSequence`, `Collection`, `Map` and `Arrays`

**Use**:

Checks element size between min and max (inclusive)

**Reference**:

Documentation

**Model**:

```java
import javax.validation.constraints.Size;

public class Message {

   //Constraint: Message must contain 10 to 500 characters, inclusive
   @Size(min = 10, max = 500)
   private String message;

   public String getMessage() {
      return message;
   }

   public void setMessage(String message) {
      this.message = message;
   }

...
}
```

**Controller**:

```java
import javax.validation.Valid;
import com.company.app.model.Message;

@Controller
public class MessageController {

...

@RequestMapping(value="/sendMessage", method=RequestMethod.POST)
public @ResponseBody String sendMessage(@Valid Message message, BindingResult result,
HttpServletResponse response){

   if(result.hasErrors()){
      String errorMessage = "";
      response.setStatus(HttpServletResponse.SC_BAD_REQUEST);
      List<ObjectError> errors = result.getAllErrors();
      for( ObjectError e : errors){
         errorMessage+= "ERROR: " + e.getDefaultMessage();
      }
      return errorMessage;
   }
   else{
      return "Validation Successful";
   }
}
}
```

### @Past / @Future

**Annotation**:

`@Past,` `@Future`

**Data Type**:

`java.util.Date`, `java.util.Calendar`, `java.time.chrono.ChronoZonedDateTime`, `java.time.Instant`, `java.time.OffsetDateTime`

**Use**:

Checks date in past / future. Use supported date type e.g. `java.util.Date`; `@Future` does not validate date strings.

**Reference**:

Documentation

**Model**:

```java
import java.util.Date;
import javax.validation.constraints.Past;
import javax.validation.constraints.Future;

public class DoctorVisit {

   //Constraint: Birthdate must be in the past
   @Past
   private Date birthDate;

   public Date getBirthDate() {
      return birthDate;
   }

   public void setBirthDate(Date birthDate) {
      this.birthDate = birthDate;
   }

   //Constraint: Schedule visit date must be in the future
   @Future
   private Date scheduledVisitDate;

   public Date getScheduledVisitDate() {
      return scheduledVisitDate;
   }

   public void setScheduledVisitDate(Date scheduledVisitDate) {
      this.scheduledVisitDate = scheduledVisitDate;
   }

...
}
```

**Controller**:

```java
import javax.validation.Valid;
import com.company.app.model.DoctorVisit;

@Controller
public class DoctorVisitController {

   ...

   @RequestMapping(value="/scheduleVisit", method=RequestMethod.POST)
   public @ResponseBody String scheduleVisit(@Valid DoctorVisit doctorvisit, BindingResult result,
   HttpServletResponse response){

      if(result.hasErrors()){
         String errorMessage = "";
         response.setStatus(HttpServletResponse.SC_BAD_REQUEST);
         List<ObjectError> errors = result.getAllErrors();
         for( ObjectError e : errors){
            errorMessage+= "ERROR: " + e.getDefaultMessage();
         }
         return errorMessage;
      }
      else{
         return "Validation Successful";
      }
   }
}
```

### Combining Constraints

Annotations combine freely. E.g. valid reviewRating between 1 and 5:

**Annotation**:

`@Min(value=),` `@Max(value=)`

**Data Type**:

`BigDecimal`, `BigInteger`, `byte`, `short`, `int`, `long` + wrappers of primitive types; HV also: any sub-type of `CharSequence` (numeric value of char sequence evaluated), any sub-type of Number

**Use**:

Checks value ≥/≤ specified minimum/maximum

**Reference:**

Documentation

**Model**:

```java
import javax.validation.constraints.Min;
import javax.validation.constraints.Max;

public class Review {

 //Constraint: Review rating must be between 1 and 5
 @Min(1)
 @Max(5)
 private int reviewRating;

 public int getReviewRating() {
   return reviewRating;
 }

 public void setReviewRating(int reviewRating) {
   this.reviewRating = reviewRating;
}
 ...
}
```

**Controller**:

```java
import javax.validation.Valid;
import com.company.app.model.ReviewRating;

@Controller
public class ReviewController {

   ...

   @RequestMapping(value="/postReview", method=RequestMethod.POST)
   public @ResponseBody String postReview(@Valid Review review, BindingResult result,
   HttpServletResponse response){

      if(result.hasErrors()){
         String errorMessage = "";
         response.setStatus(HttpServletResponse.SC_BAD_REQUEST);
         List<ObjectError> errors = result.getAllErrors();
         for( ObjectError e : errors){
            errorMessage+= "ERROR: " + e.getDefaultMessage();
         }
         return errorMessage;
      }
       else{
         return "Validation Successful";
      }
   }
}
```

### Cascading Constraints

Beans often nested or in graph. Validate whole graph w/ cascading validation: `@Valid`.

### Additional Constraints

Hibernate Validator adds convenience constraints beyond JSR303:

- `@CreditCardNumber`
- `@EAN`
- `@Email`
- `@Length`
- `@Range`
- `@ScriptAssert`
- `@URL`

See HV docs for complete list.

`@SafeHtml` deprecated (Hibernate Validator 6.1.0.Final and 6.0.18.Final release). Do not use.

## Custom Constraints

Define own constraints beyond built-ins; powerful. Out of scope here; see Hibernate Validator docs.

## Error Messages

Specify message ID in annotation to customize error messages:

```java
@Pattern(regexp = "[a-zA-Z0-9 ]+", message="article.title.error")
private String articleTitle;
```

Spring MVC looks up message ID *article.title.error* in defined MessageSource.

## References

- Jakarta Bean Validation 3.0 Specification
- Hibernate Validator 9.0: Interpolating Constraint Error Messages
