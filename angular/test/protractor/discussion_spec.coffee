describe 'Discussion Page', ->

  groupsHelper = require './helpers/groups_helper.coffee'
  discussionForm = require './helpers/discussion_form_helper.coffee'
  threadPage = require './helpers/thread_helper.coffee'
  flashHelper = require './helpers/flash_helper.coffee'
  page = require './helpers/page_helper.coffee'

  describe 'viewing while logged out', ->
    xit 'should display content for a public thread', ->
      groupsHelper.loadPath('view_open_group_as_visitor')
      groupsHelper.clickFirstThread()
      expect(threadPage.discussionTitle()).toContain('I carried a watermelon')
      expect(threadPage.signInButton()).toContain('Sign In')

  describe 'edit thread', ->
    beforeEach ->
      page.loadPath('setup_discussion')

    it 'lets you edit title and context', ->
      page.click '.thread-context__dropdown-button',
                 '.thread-context__dropdown-options-edit'
      page.fillIn('.discussion-form__title-input', 'better title')
      page.fillIn('.discussion-form__description-input', 'improved description')
      page.click('.discussion-form__update')
      page.expectText('.thread-context', 'better title')
      page.expectText('.thread-context', "improved description")

    it 'does not store cancelled thread info', ->
      page.click '.thread-context__dropdown-button',
                 '.thread-context__dropdown-options-edit'

      page.fillIn('.discussion-form__title-input', 'dumb title')
      page.fillIn('.discussion-form__description-input', 'rubbish description')

      page.click('.discussion-form__cancel')
      page.click '.thread-context__dropdown-button',
                 '.thread-context__dropdown-options-edit'

      page.expectNoText('.discussion-form__title-input', 'dumb title')
      page.expectNoText('.discussion-form__description-input', 'rubbish description')

    it 'lets you view thread revision history', ->
      page.click '.thread-context__dropdown-button',
                 '.thread-context__dropdown-options-edit'
      page.fillIn '.discussion-form__title-input', 'Revised title'
      page.fillIn '.discussion-form__description-input', 'Revised description'
      page.click '.discussion-form__update'
      page.click '.thread-context__edited-link'
      page.expectText '.revision-history-modal__body', 'Revised title'
      page.expectText '.revision-history-modal__body', 'Revised description'
      page.expectText '.revision-history-modal__body', 'What star sign are you?'

  describe 'move thread', ->
    it 'lets you move a thread', ->
      page.loadPath 'setup_multiple_discussions'
      page.click '.thread-context__dropdown-button',
                 '.thread-context__dropdown-options-move'

      page.click '.move-thread-form__group-dropdown'
      element(By.cssContainingText('option', 'Point Break')).click();
      page.click '.move-thread-form__submit'

      page.expectText '.group-theme__name--compact','Point Break'
      page.expectFlash 'Thread has been moved to Point Break'

  describe 'delete thread', ->
    beforeEach ->
      page.loadPath('setup_discussion')

    it 'lets coordinators and thread authors delete threads', ->
      threadPage.openThreadOptionsDropdown()
      threadPage.selectDeleteThreadOption()
      threadPage.confirmThreadDeletion()
      expect(flashHelper.flashMessage()).toContain('Thread deleted')
      expect(groupsHelper.groupName().isPresent()).toBe(true)
      expect(groupsHelper.groupPage()).not.toContain('What star sign are you?')

  describe 'changing thread volume', ->
    beforeEach ->
      page.loadPath('setup_discussion')

    it 'lets you change thread notification volume', ->
      expect(threadPage.threadVolumeCard()).toContain('Email proposals')
      threadPage.clickChangeInThreadVolumeCard()
      threadPage.changeThreadVolumeToLoud()
      threadPage.submitChangeVolumeForm()
      expect(threadPage.threadVolumeCard()).toContain('Email everything')

  describe 'commenting', ->
    beforeEach ->
      page.loadPath('setup_discussion')
      browser.driver.manage().window().setSize(1280, 1024);

    it 'adds a comment', ->
      threadPage.addComment('hi this is my comment')
      expect(threadPage.mostRecentComment()).toContain('hi this is my comment')

    it 'can add emojis', ->
      page.fillIn '.comment-form__comment-field', 'Here is a dragon!'
      page.click '.emoji-picker__toggle'
      page.fillIn '.emoji-picker__search', 'drag'
      page.clickFirst '.emoji-picker__icon'
      page.click '.comment-form__submit-button'
      page.expectText '.thread-item__body','Here is a dragon!'
      page.expectElement '.thread-item__body img'

    it 'replies to a comment', ->
      threadPage.addComment('original comment right heerrr')
      threadPage.replyLinkOnMostRecentComment().click()
      threadPage.addComment('hi this is my comment')
      expect(threadPage.inReplyToOnMostRecentComment()).toContain('in reply to')
      expect(flashHelper.flashMessage()).toContain('Patrick Swayze notified of reply')

    it 'likes a comment', ->
      threadPage.addComment('hi')
      threadPage.likeLinkOnMostRecentComment().click()
      expect(threadPage.likedByOnMostRecentComment()).toContain('You like this.')

    it 'mentions a user', ->
      threadPage.enterCommentText('@jennifer')
      expect(threadPage.mentionList().getText()).toContain('Jennifer Grey')
      threadPage.firstMentionOption().click()
      threadPage.submitComment()
      expect(threadPage.mostRecentComment()).toContain('@jennifergrey')

    it 'edits a comment', ->
      threadPage.addComment('original comment right hur')
      threadPage.clickThreadItemOptionsButton()
      threadPage.selectEditCommentOption()
      threadPage.editCommentText('edited comment right thur')
      threadPage.submitEditedComment()
      expect(threadPage.mostRecentComment()).toContain('edited comment right thur')

    it 'lets you view comment revision history', ->
      page.fillIn '.comment-form__comment-field', 'Comment!'
      page.click '.comment-form__submit-button'
      page.click '.thread-item__dropdown-button',
                 '.thread-item__edit-link'
      page.fillIn '.edit-comment-form__comment-field', 'Revised comment!'
      page.click  '.comment-form__submit-btn'
      page.click '.thread-item__action--view-edits',
                 '.thread-item__action--view-edits'
      page.expectText '.revision-history-modal__body', 'Revised comment!'
      page.expectText '.revision-history-modal__body', 'Comment!'

    it 'deletes a comment', ->
      threadPage.addComment('original comment right hur')
      threadPage.clickThreadItemOptionsButton()
      threadPage.selectDeleteCommentOption()
      threadPage.confirmCommentDeletion()
      expect(threadPage.activityPanel()).not.toContain('original comment right thur')

    xit 'hides member actions from visitors', ->
      threadPage.loadWithPublicContent()
      expect(threadPage.commentForm().isPresent()).toBe(false)
      expect(threadPage.threadOptionsDropdown().isPresent()).toBe(false)
      expect(threadPage.volumeOptions().isPresent()).toBe(false)
