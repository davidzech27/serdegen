pub type Message {
  UserMessage(UserMessage)
  PostMessage(PostMessage)
}

pub type UserMessage {
  CreateUser(username: String)
  ChangeUsername(from: String, to: String)
  DeleteUser(username: String)
}

pub type PostMessage {
  CreatePost(content: String, author: String)
  EditPost(id: Int, new_content: String)
  DeletePost(id: Int)
  LikePost(id: Int, liker: String)
  CommentOnPost(id: Int, commenter: String, comment: String)
}
