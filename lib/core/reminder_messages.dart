class ReminderMessage {
  final String textAr;
  final String textEn;

  const ReminderMessage({
    required this.textAr,
    required this.textEn,
  });
}

class ReminderMessages {
  static const List<ReminderMessage> startWird = [
    ReminderMessage(
      textAr: "﴿ وَرَتِّلِ الْقُرْآنَ تَرْتِيلًا ﴾\nحان موعد وردك اليومي، فاجعل لك نصيبًا من كلام الله.",
      textEn: "\"And recite the Quran with measured recitation.\"\nIt is time for your daily Wird, so make for yourself a portion of the Words of Allah.",
    ),
    ReminderMessage(
      textAr: "«خيركم من تعلَّم القرآن وعلَّمه»\nابدأ وردك اليومي، فالخير في صحبة القرآن.",
      textEn: "\"The best among you are those who learn the Quran and teach it.\"\nStart your daily Wird, for goodness lies in the companionship of the Quran.",
    ),
    ReminderMessage(
      textAr: "﴿ أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ ﴾\nاجعل دقائق من يومك مع القرآن، ففيه الطمأنينة.",
      textEn: "\"Unquestionably, by the remembrance of Allah hearts are assured.\"\nSpend a few minutes of your day with the Quran, for in it is tranquility.",
    ),
    ReminderMessage(
      textAr: "اليوم صفحة جديدة مع كتاب الله...\nابدأ وردك، فما تقرؤه اليوم يكون نورًا لك غدًا.",
      textEn: "Today is a new page with the Book of Allah...\nStart your Wird, for what you read today will be a light for you tomorrow.",
    ),
  ];

  static const List<ReminderMessage> incompleteWird = [
    ReminderMessage(
      textAr: "ما زال وردك ينتظرك...\n﴿ وَقُرْآنَ الْفَجْرِ ۖ إِنَّ قُرْآنَ الْفَجْرِ كَانَ مَشْهُودًا ﴾",
      textEn: "Your Wird is still waiting for you...\n\"And the recitation of dawn; indeed, the recitation of dawn is ever witnessed.\"",
    ),
    ReminderMessage(
      textAr: "لم يبقَ إلا القليل...\nأتمَّ وردك، فـ «أحب الأعمال إلى الله أدومها وإن قل».",
      textEn: "Only a little remains...\nComplete your Wird, for \"the most beloved of deeds to Allah are those that are most consistent, even if they are small.\"",
    ),
    ReminderMessage(
      textAr: "لا تدع يومك يمضي دون أن تختم وردك،\nفلعل آيةً تقرؤها تكون سببًا في هداية قلبك.",
      textEn: "Do not let your day pass without completing your Wird, for perhaps a verse you read will be the cause of guiding your heart.",
    ),
    ReminderMessage(
      textAr: "اقتربت نهاية يومك، وما زال لك موعد مع القرآن...\nأكمل وردك، فإن خير الزاد كلام الله.",
      textEn: "The end of your day is approaching, and you still have an appointment with the Quran...\nComplete your Wird, for the best provision is the Word of Allah.",
    ),
  ];

  static const List<ReminderMessage> completedWird = [
    ReminderMessage(
      textAr: "بارك الله فيك.\nأتممت وردك اليومي، نسأل الله أن يجعل القرآن ربيع قلبك ونور صدرك.",
      textEn: "May Allah bless you.\nYou have completed your daily Wird. We ask Allah to make the Quran the spring of your heart and the light of your chest.",
    ),
    ReminderMessage(
      textAr: "هنيئًا لك إتمام وردك.\n﴿ إِنَّ هَٰذَا الْقُرْآنَ يَهْدِي لِلَّتِي هِيَ أَقْوَمُ ﴾\nنسأل الله أن يجعلك من أهل القرآن.",
      textEn: "Congratulations on completing your Wird.\n\"Indeed, this Quran guides to that which is most suitable.\"\nWe ask Allah to make you among the people of the Quran.",
    ),
    ReminderMessage(
      textAr: "ما أجمل أن يُختتم يومك بكلام الله.\nتقبّل الله منك، وبارك لك في تلاوتك.",
      textEn: "How beautiful it is to end your day with the Words of Allah.\nMay Allah accept from you and bless your recitation.",
    ),
    ReminderMessage(
      textAr: "اليوم أكرمك الله بإتمام وردك،\nفاثبت على هذه النعمة، فإن «أحب الأعمال إلى الله أدومها وإن قل».",
      textEn: "Today Allah has graced you with completing your Wird.\nSo remain steadfast upon this blessing, for \"the most beloved of deeds to Allah are those that are most consistent, even if they are small.\"",
    ),
  ];
}
