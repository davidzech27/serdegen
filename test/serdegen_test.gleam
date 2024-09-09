import gleam/dict
import gleam/list
import gleam/option
import gleeunit
import gleeunit/should

import internal/codegen/parse
import internal/file

pub fn main() {
  gleeunit.main()
}

pub fn parse_test() {
  file.read_files("./test/test_files", with_extension: ".gleam")
  |> should.be_ok
  |> list.map(parse.parse_type_file)
  |> list.map(should.be_ok)
  |> list.flatten
  |> should.equal([
    parse.TypeDefinition("Person", [
      parse.Variant("Person", [
        parse.Field(option.Some("name"), parse.StringReference),
        parse.Field(option.Some("age"), parse.IntReference),
        parse.Field(option.Some("is_nice"), parse.BoolReference),
        parse.Field(
          option.Some("grocery_list"),
          parse.ListReference(
            parse.TupleReference([parse.StringReference, parse.IntReference]),
          ),
        ),
        parse.Field(
          option.Some("pet"),
          parse.OptionReference(parse.CustomReference("Pet")),
        ),
      ]),
      parse.Variant("Imaginary", [parse.Field(option.None, parse.IntReference)]),
      parse.Variant("Wizard", [
        parse.Field(option.Some("level"), parse.IntReference),
      ]),
    ]),
    parse.TypeDefinition("Pet", [
      parse.Variant("Pet", [
        parse.Field(option.Some("name"), parse.StringReference),
        parse.Field(
          option.Some("enemy"),
          parse.OptionReference(parse.CustomReference("Person")),
        ),
        parse.Field(
          option.Some("person_rankings"),
          parse.DictReference(
            parse.CustomReference("Person"),
            parse.IntReference,
          ),
        ),
        parse.Field(
          option.Some("favorite_numbers"),
          parse.DictReference(parse.IntReference, parse.FloatReference),
        ),
        parse.Field(
          option.Some("vocabulary_frequency"),
          parse.DictReference(parse.StringReference, parse.FloatReference),
        ),
      ]),
    ]),
    parse.TypeDefinition("Message", [
      parse.Variant("UserMessage", [
        parse.Field(option.None, parse.CustomReference("UserMessage")),
      ]),
      parse.Variant("PostMessage", [
        parse.Field(option.None, parse.CustomReference("PostMessage")),
      ]),
    ]),
    parse.TypeDefinition("UserMessage", [
      parse.Variant("CreateUser", [
        parse.Field(option.Some("username"), parse.StringReference),
      ]),
      parse.Variant("ChangeUsername", [
        parse.Field(option.Some("from"), parse.StringReference),
        parse.Field(option.Some("to"), parse.StringReference),
      ]),
      parse.Variant("DeleteUser", [
        parse.Field(option.Some("username"), parse.StringReference),
      ]),
    ]),
    parse.TypeDefinition("PostMessage", [
      parse.Variant("CreatePost", [
        parse.Field(option.Some("content"), parse.StringReference),
        parse.Field(option.Some("author"), parse.StringReference),
      ]),
      parse.Variant("EditPost", [
        parse.Field(option.Some("id"), parse.IntReference),
        parse.Field(option.Some("new_content"), parse.StringReference),
      ]),
      parse.Variant("DeletePost", [
        parse.Field(option.Some("id"), parse.IntReference),
      ]),
      parse.Variant("LikePost", [
        parse.Field(option.Some("id"), parse.IntReference),
        parse.Field(option.Some("liker"), parse.StringReference),
      ]),
      parse.Variant("CommentOnPost", [
        parse.Field(option.Some("id"), parse.IntReference),
        parse.Field(option.Some("commenter"), parse.StringReference),
        parse.Field(option.Some("comment"), parse.StringReference),
      ]),
    ]),
  ])
}

import test_files/entities
import test_files/entities_json
import test_files/message
import test_files/message_json

pub fn json_test() {
  let person =
    entities.Person(
      name: "Alice",
      age: 30,
      is_nice: True,
      grocery_list: [#("apples", 3), #("bananas", 2)],
      pet: option.None,
    )

  person
  |> entities_json.serialize_person()
  |> entities_json.deserialize_person()
  |> should.be_ok
  |> should.equal(person)

  let wizard = entities.Wizard(level: 10)

  wizard
  |> entities_json.serialize_person()
  |> entities_json.deserialize_person()
  |> should.be_ok
  |> should.equal(wizard)

  let imaginary_friend = entities.Imaginary(42)

  imaginary_friend
  |> entities_json.serialize_person()
  |> entities_json.deserialize_person()
  |> should.be_ok
  |> should.equal(imaginary_friend)

  let my_pet =
    entities.Pet(
      name: "Fluffy",
      enemy: option.None,
      person_rankings: dict.from_list([
        #(person, -100),
        #(imaginary_friend, 10),
        #(wizard, 100_000),
      ]),
      favorite_numbers: dict.from_list([#(42, 3.14), #(7, 2.718)]),
      vocabulary_frequency: dict.from_list([#("meow", 0.8), #("purr", 0.2)]),
    )

  my_pet
  |> entities_json.serialize_pet()
  |> entities_json.deserialize_pet()
  |> should.be_ok
  |> should.equal(my_pet)

  let create_user = message.UserMessage(message.CreateUser(username: "bob"))
  let change_username =
    message.UserMessage(message.ChangeUsername(from: "bob", to: "alice"))
  let delete_user = message.UserMessage(message.DeleteUser(username: "alice"))

  create_user
  |> message_json.serialize()
  |> message_json.deserialize()
  |> should.be_ok
  |> should.equal(create_user)

  change_username
  |> message_json.serialize()
  |> message_json.deserialize()
  |> should.be_ok
  |> should.equal(change_username)

  delete_user
  |> message_json.serialize()
  |> message_json.deserialize()
  |> should.be_ok
  |> should.equal(delete_user)

  let create_post =
    message.PostMessage(message.CreatePost(
      content: "Hello, world!",
      author: "bob",
    ))
  let edit_post =
    message.PostMessage(message.EditPost(id: 1, new_content: "Updated content"))
  let delete_post = message.PostMessage(message.DeletePost(id: 1))
  let like_post = message.PostMessage(message.LikePost(id: 1, liker: "alice"))
  let comment_post =
    message.PostMessage(message.CommentOnPost(
      id: 1,
      commenter: "charlie",
      comment: "Nice post!",
    ))

  create_post
  |> message_json.serialize()
  |> message_json.deserialize()
  |> should.be_ok
  |> should.equal(create_post)

  edit_post
  |> message_json.serialize()
  |> message_json.deserialize()
  |> should.be_ok
  |> should.equal(edit_post)

  delete_post
  |> message_json.serialize()
  |> message_json.deserialize()
  |> should.be_ok
  |> should.equal(delete_post)

  like_post
  |> message_json.serialize()
  |> message_json.deserialize()
  |> should.be_ok
  |> should.equal(like_post)

  comment_post
  |> message_json.serialize()
  |> message_json.deserialize()
  |> should.be_ok
  |> should.equal(comment_post)
}
