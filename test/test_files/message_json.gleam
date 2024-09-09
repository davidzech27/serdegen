// GENERATED CODE

import gleam/dynamic
import gleam/json
import gleam/result

import test_files/message

pub fn serialize(message: message.Message) {
  to_json(message)
  |> json.to_string
}

fn to_json(message: message.Message) {
  case message {
    message.UserMessage(field0) ->
      json.object([
        #("variant", json.string("UserMessage")),
        #("value",
          json.object([
            #("0", usermessage_to_json(field0)),
          ])
        ),
      ])
    message.PostMessage(field0) ->
      json.object([
        #("variant", json.string("PostMessage")),
        #("value",
          json.object([
            #("0", postmessage_to_json(field0)),
          ])
        ),
      ])
  }
}

pub fn deserialize(message_string: String) {
  json.decode(message_string, from_dynamic)
}

fn from_dynamic(message_dynamic: dynamic.Dynamic) {
  dynamic.decode2(
    fn(variant, value) {
      case variant {
        "UserMessage" ->
          Ok(dynamic.decode1(
            message.UserMessage,
            dynamic.field("0", usermessage_from_dynamic),
          )(value))
        "PostMessage" ->
          Ok(dynamic.decode1(
            message.PostMessage,
            dynamic.field("0", postmessage_from_dynamic),
          )(value))
        _ ->
          Error([
            dynamic.DecodeError(
              expected: "UserMessage | PostMessage",
              found: variant,
              path: ["variant"],
            ),
          ])
      }
    },
    dynamic.field("variant", dynamic.string),
    dynamic.field("value", dynamic.dynamic),
  )(message_dynamic)
  |> result.flatten
  |> result.flatten
}

pub fn serialize_usermessage(usermessage: message.UserMessage) {
  usermessage_to_json(usermessage)
  |> json.to_string
}

fn usermessage_to_json(usermessage: message.UserMessage) {
  case usermessage {
    message.CreateUser(username) ->
      json.object([
        #("variant", json.string("CreateUser")),
        #("value",
          json.object([
            #("username", json.string(username)),
          ])
        ),
      ])
    message.ChangeUsername(from, to) ->
      json.object([
        #("variant", json.string("ChangeUsername")),
        #("value",
          json.object([
            #("from", json.string(from)),
            #("to", json.string(to)),
          ])
        ),
      ])
    message.DeleteUser(username) ->
      json.object([
        #("variant", json.string("DeleteUser")),
        #("value",
          json.object([
            #("username", json.string(username)),
          ])
        ),
      ])
  }
}

pub fn deserialize_usermessage(usermessage_string: String) {
  json.decode(usermessage_string, usermessage_from_dynamic)
}

fn usermessage_from_dynamic(usermessage_dynamic: dynamic.Dynamic) {
  dynamic.decode2(
    fn(variant, value) {
      case variant {
        "CreateUser" ->
          Ok(dynamic.decode1(
            message.CreateUser,
            dynamic.field("username", dynamic.string),
          )(value))
        "ChangeUsername" ->
          Ok(dynamic.decode2(
            message.ChangeUsername,
            dynamic.field("from", dynamic.string),
            dynamic.field("to", dynamic.string),
          )(value))
        "DeleteUser" ->
          Ok(dynamic.decode1(
            message.DeleteUser,
            dynamic.field("username", dynamic.string),
          )(value))
        _ ->
          Error([
            dynamic.DecodeError(
              expected: "CreateUser | ChangeUsername | DeleteUser",
              found: variant,
              path: ["variant"],
            ),
          ])
      }
    },
    dynamic.field("variant", dynamic.string),
    dynamic.field("value", dynamic.dynamic),
  )(usermessage_dynamic)
  |> result.flatten
  |> result.flatten
}

pub fn serialize_postmessage(postmessage: message.PostMessage) {
  postmessage_to_json(postmessage)
  |> json.to_string
}

fn postmessage_to_json(postmessage: message.PostMessage) {
  case postmessage {
    message.CreatePost(content, author) ->
      json.object([
        #("variant", json.string("CreatePost")),
        #("value",
          json.object([
            #("content", json.string(content)),
            #("author", json.string(author)),
          ])
        ),
      ])
    message.EditPost(id, new_content) ->
      json.object([
        #("variant", json.string("EditPost")),
        #("value",
          json.object([
            #("id", json.int(id)),
            #("new_content", json.string(new_content)),
          ])
        ),
      ])
    message.DeletePost(id) ->
      json.object([
        #("variant", json.string("DeletePost")),
        #("value",
          json.object([
            #("id", json.int(id)),
          ])
        ),
      ])
    message.LikePost(id, liker) ->
      json.object([
        #("variant", json.string("LikePost")),
        #("value",
          json.object([
            #("id", json.int(id)),
            #("liker", json.string(liker)),
          ])
        ),
      ])
    message.CommentOnPost(id, commenter, comment) ->
      json.object([
        #("variant", json.string("CommentOnPost")),
        #("value",
          json.object([
            #("id", json.int(id)),
            #("commenter", json.string(commenter)),
            #("comment", json.string(comment)),
          ])
        ),
      ])
  }
}

pub fn deserialize_postmessage(postmessage_string: String) {
  json.decode(postmessage_string, postmessage_from_dynamic)
}

fn postmessage_from_dynamic(postmessage_dynamic: dynamic.Dynamic) {
  dynamic.decode2(
    fn(variant, value) {
      case variant {
        "CreatePost" ->
          Ok(dynamic.decode2(
            message.CreatePost,
            dynamic.field("content", dynamic.string),
            dynamic.field("author", dynamic.string),
          )(value))
        "EditPost" ->
          Ok(dynamic.decode2(
            message.EditPost,
            dynamic.field("id", dynamic.int),
            dynamic.field("new_content", dynamic.string),
          )(value))
        "DeletePost" ->
          Ok(dynamic.decode1(
            message.DeletePost,
            dynamic.field("id", dynamic.int),
          )(value))
        "LikePost" ->
          Ok(dynamic.decode2(
            message.LikePost,
            dynamic.field("id", dynamic.int),
            dynamic.field("liker", dynamic.string),
          )(value))
        "CommentOnPost" ->
          Ok(dynamic.decode3(
            message.CommentOnPost,
            dynamic.field("id", dynamic.int),
            dynamic.field("commenter", dynamic.string),
            dynamic.field("comment", dynamic.string),
          )(value))
        _ ->
          Error([
            dynamic.DecodeError(
              expected: "CreatePost | EditPost | DeletePost | LikePost | CommentOnPost",
              found: variant,
              path: ["variant"],
            ),
          ])
      }
    },
    dynamic.field("variant", dynamic.string),
    dynamic.field("value", dynamic.dynamic),
  )(postmessage_dynamic)
  |> result.flatten
  |> result.flatten
}