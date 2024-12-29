package tests

import Generators
import PermutationScope
import TestCase
import asList
import nullable
import oneOf
import org.thoughtcrime.securesms.backup.v2.proto.ChatItem
import org.thoughtcrime.securesms.backup.v2.proto.ContactAttachment
import org.thoughtcrime.securesms.backup.v2.proto.ContactMessage
import org.thoughtcrime.securesms.backup.v2.proto.Frame

/**
 * Every reasonable permutation of ChatItem.ContactMessage
 */
object ChatItemContactMessageTestCase : TestCase("chat_item_contact_message") {

  override fun PermutationScope.execute() {
    frames += StandardFrames.MANDATORY_FRAMES

    frames += StandardFrames.recipientAlice
    frames += StandardFrames.chatAlice

    val sendStatusGenerator = Generators.sendStatus(
      recipientIdGenerator = Generators.single(StandardFrames.recipientAlice.recipient!!.id)
    )

    val (incomingGenerator, outgoingGenerator) = oneOf(
      Generators.permutation {
        frames += ChatItem.IncomingMessageDetails(
          dateReceived = someIncrementingTimestamp(),
          dateServerSent = someIncrementingTimestamp(),
          read = someBoolean(),
          sealedSender = someBoolean()
        )
      },
      Generators.permutation {
        frames += ChatItem.OutgoingMessageDetails(
          sendStatus = listOf(some(sendStatusGenerator))
        )
      }
    )

    val incoming = some(incomingGenerator)
    val outgoing = some(outgoingGenerator)

    frames += Frame(
      chatItem = ChatItem(
        chatId = StandardFrames.chatAlice.chat!!.id,
        authorId = if (outgoing != null) {
          StandardFrames.recipientSelf.recipient!!.id
        } else {
          StandardFrames.recipientAlice.recipient!!.id
        },
        dateSent = someNonZeroTimestamp(),
        incoming = incoming as ChatItem.IncomingMessageDetails?,
        outgoing = outgoing as ChatItem.OutgoingMessageDetails?,
        contactMessage = ContactMessage(
          contact = Generators.permutation<ContactAttachment> {
            frames += ContactAttachment(
              name = ContactAttachment.Name(
                givenName = some(Generators.firstNames()),
                familyName = some(Generators.lastNames().nullable()),
                middleName = some(Generators.firstNames().nullable()),
                prefix = some(Generators.list(null, "Mr.", "Mrs.", "Miss")),
                suffix = some(Generators.list(null, "Jr.", "Sr.", "III")),
                nickname = some(Generators.firstNames().nullable())
              ),
              number = Generators.permutation<ContactAttachment.Phone> {
                frames += ContactAttachment.Phone(
                  value_ = someE164().toString(),
                  type = someEnum(
                    ContactAttachment.Phone.Type::class.java,
                    excluding = ContactAttachment.Phone.Type.UNKNOWN
                  ),
                  label = someNullableString()
                )
              }.asList(0, 1, 2).let { some(it) },
              email = Generators.permutation<ContactAttachment.Email> {
                frames += ContactAttachment.Email(
                  value_ = some(Generators.emails()),
                  type = someEnum(
                    ContactAttachment.Email.Type::class.java,
                    excluding = ContactAttachment.Email.Type.UNKNOWN
                  ),
                  label = someNullableString()
                )
              }.asList(0, 1, 2).let { some(it) },
              address = Generators.permutation<ContactAttachment.PostalAddress> {
                // All-empty addresses are invalid, so ensure that at least one
                // address field has a non-null, non-empty string.
                val streetGenerator = Generators.list(null, SeededRandom.string(), SeededRandom.string())
                val poBoxGenerator = Generators.list(SeededRandom.string(), null, SeededRandom.string())

                frames += ContactAttachment.PostalAddress(
                  type = someEnum(
                    ContactAttachment.PostalAddress.Type::class.java,
                    excluding = ContactAttachment.PostalAddress.Type.UNKNOWN
                  ),
                  label = someNullableString(),
                  street = some(streetGenerator),
                  pobox = some(poBoxGenerator),
                  neighborhood = someNullableString(),
                  city = someNullableString(),
                  region = someNullableString(),
                  postcode = someNullableString(),
                  country = someNullableString()
                )
              }.asList(0, 1, 2).let { some(it) },
              organization = someNullableString(),
              avatar = some(Generators.avatarFilePointer().nullable())
            )
          }.asList(1).let { some(it) }
        )
      )
    )
  }
}
